# frozen_string_literal: true
# typed: false

require "net/http"
require "uri"
require "json"

module Perenual
  # Minimal REST client for the Perenual plant API (perenual.com), scoped to one
  # {GardenConnection}'s API key. Covers what the catalog needs:
  #
  #   * search(query) -- species-list search, returns lightweight summaries
  #   * details(id)   -- full care record for one species
  #
  # Perenual is a public internet host, so every request goes through
  # {SafeHttp}'s SSRF guard. The free tier is rate-limited; a 429 raises
  # {RateLimitError} so callers can tell the user to try later rather than
  # treating it as a hard failure.
  class Client
    BASE = "https://perenual.com/api/v2"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20

    # `:cycle` shadows Struct's Enumerable#cycle -- intentional; we only ever
    # read the member, never iterate the struct.
    # rubocop:disable Lint/StructNewOverride
    Summary = Struct.new(
      :perenual_id, :common_name, :scientific_name, :cycle, :image_url,
      keyword_init: true
    )

    Details = Struct.new(
      :perenual_id, :common_name, :scientific_name, :cycle, :sunlight, :watering,
      :hardiness_min, :hardiness_max, :edible, :image_url, :external_url,
      keyword_init: true
    )
    # rubocop:enable Lint/StructNewOverride

    # @param connection [GardenConnection]
    def initialize(connection)
      @connection = connection
    end

    # @param query [String]
    # @return [Array<Summary>]
    # @raise [Perenual::Error]
    def search(query)
      body = get_json("/species-list", q: query.to_s.strip)
      Array(body["data"]).filter_map { |row| summary_from(row) }
    end

    # @param perenual_id [Integer]
    # @return [Details]
    # @raise [Perenual::Error]
    def details(perenual_id)
      row = get_json("/species/details/#{perenual_id.to_i}")
      details_from(row)
    end

    private

    def get_json(path, params = {})
      raise AuthError, "no API key configured" if @connection&.api_key.blank?

      uri = URI.parse("#{BASE}#{path}")
      uri.query = URI.encode_www_form(params.merge(key: @connection.api_key))
      SafeHttp.validate_uri!(uri)

      resp = perform(uri)
      handle_status(resp)
      JSON.parse(resp.body.to_s)
    rescue JSON::ParserError => e
      raise Error, "invalid response from Perenual (#{e.message})"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
           OpenSSL::SSL::SSLError, SafeHttp::BlockedRequestError => e
      raise Error, "could not reach Perenual (#{e.class})"
    end

    def perform(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.request(Net::HTTP::Get.new(uri.request_uri, "Accept" => "application/json"))
    end

    def handle_status(resp)
      case resp
      when Net::HTTPSuccess then nil
      when Net::HTTPUnauthorized, Net::HTTPForbidden
        raise AuthError, "Perenual rejected the API key (HTTP #{resp.code})"
      when Net::HTTPTooManyRequests
        raise RateLimitError, "Perenual rate limit reached (HTTP 429)"
      else
        raise Error, "Perenual returned HTTP #{resp.code}"
      end
    end

    def summary_from(row)
      id = row["id"]
      return nil if id.blank?

      Summary.new(
        perenual_id:     id,
        common_name:     row["common_name"].presence || Array(row["scientific_name"]).first,
        scientific_name: Array(row["scientific_name"]).first,
        cycle:           row["cycle"].presence,
        image_url:       image_url_from(row)
      )
    end

    def details_from(row)
      Details.new(
        perenual_id:     row["id"],
        common_name:     row["common_name"].presence || Array(row["scientific_name"]).first,
        scientific_name: Array(row["scientific_name"]).first,
        cycle:           row["cycle"].presence,
        sunlight:        Array(row["sunlight"]).first,
        watering:        row["watering"].presence,
        hardiness_min:   dig_zone(row, "min"),
        hardiness_max:   dig_zone(row, "max"),
        edible:          [row["edible_fruit"], row["edible_leaf"], row["cuisine"]].any? { |v| v == true },
        image_url:       image_url_from(row),
        external_url:    ("https://perenual.com/plant-database-search-guide/species/#{row["id"]}" if row["id"])
      )
    end

    def image_url_from(row)
      img = row["default_image"]
      return nil unless img.is_a?(Hash)

      img["regular_url"].presence || img["medium_url"].presence || img["thumbnail"].presence
    end

    def dig_zone(row, key)
      zone = row["hardiness"]
      return nil unless zone.is_a?(Hash)

      Integer(zone[key], exception: false)
    end
  end
end
