# frozen_string_literal: true
# typed: false

require "net/http"
require "uri"

module Garden
  # Looks up the cadastral parcel (Flurstück) at a map point via the
  # Bundesland's open ALKIS WFS (see {Garden::MapSources}, `parcels:` entry).
  # Returns the parcel's outline plus its *official* surveyed area
  # ("amtliche Fläche") and location text -- the authoritative measurements
  # the garden map shows as a reference layer.
  #
  # Query mechanics (verified against LGLN Niedersachsen `alkis_wfs_einfach`):
  # WFS 2.0 GetFeature on the parcel feature type with a tiny BBOX around the
  # clicked point in EPSG:4326 -- the doorman gateway rejects FES XML filters
  # on GET, but a ~1 m box behaves like a point-intersects query. The response
  # is GML only (no GeoJSON), axis order lat lon; parsed with Nokogiri.
  # Requests run server-side: the endpoints publish no CORS headers.
  module ParcelLookup
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20
    # Half-side of the query box: ~1 m in degrees latitude.
    BOX_HALF_DEG = 1e-5

    Parcel = Struct.new(:boundary, :area_sqm, :label, :parcel_key, keyword_init: true)

    class << self
      # @param lat [Float]
      # @param lng [Float]
      # @param source [Hash] a MapSources `parcels:` entry ({url:, type_name:})
      # @return [Parcel, nil] nil when no parcel found or the service failed
      def at(lat:, lng:, source:)
        return nil if source.blank?

        xml = fetch(build_uri(lat.to_f, lng.to_f, source))
        return nil if xml.blank?

        parse(xml)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
             OpenSSL::SSL::SSLError, SafeHttp::BlockedRequestError => e
        Rails.logger.warn("[Garden::ParcelLookup] lookup failed: #{e.class}: #{e.message}")
        nil
      end

      private

      def build_uri(lat, lng, source)
        uri = URI.parse(source[:url])
        uri.query = URI.encode_www_form(
          SERVICE: "WFS", VERSION: "2.0.0", REQUEST: "GetFeature",
          TYPENAMES: source[:type_name],
          SRSNAME: "urn:ogc:def:crs:EPSG::4326",
          BBOX: [lat - BOX_HALF_DEG, lng - BOX_HALF_DEG,
                 lat + BOX_HALF_DEG, lng + BOX_HALF_DEG,
                 "urn:ogc:def:crs:EPSG::4326"].join(","),
          COUNT: 1
        )
        SafeHttp.validate_uri!(uri)
      end

      def fetch(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = uri.scheme == "https"
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        resp = http.request(Net::HTTP::Get.new(uri.request_uri))
        resp.is_a?(Net::HTTPSuccess) ? resp.body.to_s : nil
      end

      # Pull the first member's exterior ring, official area and location text
      # out of the GML. remove_namespaces! keeps the XPath independent of the
      # per-state schema namespace (LGLN uses the adv "alkis-vereinfacht" one).
      def parse(xml)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        member = doc.at_xpath("//member/*")
        return nil unless member

        ring = pos_list_to_ring(member.at_xpath(".//exterior//posList")&.text)
        return nil if ring.length < 3

        Parcel.new(
          boundary:   ring,
          area_sqm:   member.at_xpath("./flaeche")&.text&.to_f,
          label:      member.at_xpath("./lagebeztxt")&.text.presence,
          parcel_key: member.at_xpath("./flstkennz")&.text.presence
        )
      end

      # "lat lng lat lng ..." (EPSG:4326 urn axis order) -> [{lat:, lng:}, ...]
      def pos_list_to_ring(pos_list)
        values = pos_list.to_s.split.map(&:to_f)
        values.each_slice(2).filter_map do |latitude, longitude|
          { lat: latitude, lng: longitude } if longitude
        end
      end
    end
  end
end
