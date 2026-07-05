# frozen_string_literal: true
# typed: false

module Garden
  # Planar geometry for garden-scale polygons on WGS84 coordinates. Vertices
  # are projected to local meters with an equirectangular approximation around
  # the ring's mean latitude (x = R*lng*cos(lat0), y = R*lat) and measured with
  # the shoelace formula. At garden extents (well under a kilometer) the
  # projection error is far below the accuracy of hand-traced polygons, so no
  # geo library is needed. The JS map controller mirrors the same formulas for
  # its live readout; the stored value always comes from here.
  module Geometry
    # WGS84/WebMercator sphere radius -- matches what Leaflet uses client-side.
    EARTH_RADIUS_M = 6_378_137.0

    class << self
      # Area of a closed ring given as [{"lat" => .., "lng" => ..}, ...]
      # (string or symbol keys; last->first edge implied).
      # @param ring [Array<Hash>]
      # @return [Float] square meters, 2 decimals, 0.0 for degenerate input
      def polygon_area_sqm(ring)
        pts = project(ring)
        return 0.0 if pts.length < 3

        sum = pts.each_index.sum do |i|
          x1, y1 = pts[i]
          x2, y2 = pts[(i + 1) % pts.length]
          (x1 * y2) - (x2 * y1)
        end
        (sum.abs / 2.0).round(2)
      end

      # Length of each edge of the ring, including the closing edge.
      # @param ring [Array<Hash>]
      # @return [Array<Float>] meters per edge, 2 decimals
      def edge_lengths_m(ring)
        pts = project(ring)
        return [] if pts.length < 2

        pts.each_index.map do |i|
          x1, y1 = pts[i]
          x2, y2 = pts[(i + 1) % pts.length]
          Math.hypot(x2 - x1, y2 - y1).round(2)
        end
      end

      private

      # @return [Array<Array(Float, Float)>] [x, y] in meters, local frame
      def project(ring)
        ring = Array(ring).map { |p| [p["lat"] || p[:lat], p["lng"] || p[:lng]] }
        ring = ring.select { |lat, lng| lat.is_a?(Numeric) && lng.is_a?(Numeric) }
        return [] if ring.empty?

        lat0 = ring.sum { |lat, _| lat } / ring.length
        cos0 = Math.cos(lat0 * Math::PI / 180)
        ring.map do |lat, lng|
          [EARTH_RADIUS_M * (lng * Math::PI / 180) * cos0,
           EARTH_RADIUS_M * (lat * Math::PI / 180)]
        end
      end
    end
  end
end
