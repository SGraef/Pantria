# frozen_string_literal: true
# typed: false

require "net/http"
require "uri"
require "json"

module Garden
  # One-shot address -> coordinates lookup for the garden map, via the public
  # Nominatim (OpenStreetMap) instance. Runs server-side only: Nominatim's
  # usage policy wants an identifying User-Agent, and the household address
  # shouldn't leak into client-side requests. We do a single lookup per save
  # (result lands in the settings' viewport), which is far inside the 1 req/s
  # policy. Goes through {SafeHttp} like every outbound fetch.
  module Geocoder
    ENDPOINT = "https://nominatim.openstreetmap.org/search"
    USER_AGENT = "Pantria-Homestead/1.0 (self-hosted household app; garden map)"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    Result = Struct.new(:lat, :lng, :display_name, keyword_init: true)

    class << self
      # @param query [String] free-text address
      # @return [Result, nil] nil when nothing matched or the lookup failed
      def search(query)
        query = query.to_s.strip
        return nil if query.blank?

        uri = URI.parse(ENDPOINT)
        uri.query = URI.encode_www_form(q: query, format: "jsonv2", limit: 1, countrycodes: "de")
        SafeHttp.validate_uri!(uri)

        row = Array(fetch_json(uri)).first
        return nil unless row.is_a?(Hash) && row["lat"] && row["lon"]

        Result.new(lat: row["lat"].to_f, lng: row["lon"].to_f,
                   display_name: row["display_name"].to_s)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
             OpenSSL::SSL::SSLError, JSON::ParserError, SafeHttp::BlockedRequestError => e
        Rails.logger.warn("[Garden::Geocoder] lookup failed: #{e.class}: #{e.message}")
        nil
      end

      private

      def fetch_json(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        resp = http.request(Net::HTTP::Get.new(uri.request_uri,
                                               "Accept"     => "application/json",
                                               "User-Agent" => USER_AGENT))
        return nil unless resp.is_a?(Net::HTTPSuccess)

        JSON.parse(resp.body.to_s)
      end
    end
  end
end
