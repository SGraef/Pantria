# frozen_string_literal: true
# typed: false

# Per-household garden map configuration and the one geometry the map
# captures: the Grundstück (property boundary), traced over the official
# imagery or adopted from the ALKIS parcel. Beds are NOT mapped -- they live
# in the to-scale planner, which uses this outline as its backdrop.
#
# `mode` controls whether the map section is offered at all: "map" shows the
# Leaflet map over the Bundesland's WMS layers; "lite" hides it for regions
# without an open WMS (the planner works either way).
#
# Deliberately separate from {GardenConnection} (the Perenual API binding):
# the map works without any Perenual key. Admin-only to edit -- the custom
# URLs end up in every member's browser -- but visible to all members.
class GardenMapSetting < ApplicationRecord
  belongs_to :household

  MODES = %w[map lite].freeze

  # Official parcels arrive with many surveyed vertices; stay generous.
  MAX_PROPERTY_VERTICES = 500

  # Geographic center of Germany; a fresh map starts zoomed out over the
  # whole country until the household pans to their garden and saves.
  DEFAULT_CENTER = [51.163, 10.447].freeze
  DEFAULT_ZOOM = 6

  validates :mode, inclusion: { in: MODES }
  validates :bundesland,
            inclusion:   { in: -> { Garden::MapSources::KEYS + [Garden::MapSources::CUSTOM] } },
            allow_blank: true
  validates :zoom, numericality: { only_integer: true, in: 1..22 }, allow_nil: true
  validates :center_lat, numericality: { in: -90..90 }, allow_nil: true
  validates :center_lng, numericality: { in: -180..180 }, allow_nil: true
  validates :custom_dop_url, :custom_alkis_url, length: { maximum: 500 }
  validate :custom_urls_are_http
  validate :property_boundary_shape

  before_save :recompute_property_area

  def map_mode?  = mode == "map"
  def lite_mode? = mode == "lite"

  # @return [Boolean] true once the Grundstück has been captured
  def property? = property_boundary.present?

  # @return [Array(Float, Float)] saved viewport center or the Germany default
  def effective_center
    return DEFAULT_CENTER unless center_lat && center_lng

    [center_lat.to_f, center_lng.to_f]
  end

  # @return [Integer]
  def effective_zoom
    zoom || DEFAULT_ZOOM
  end

  private

  # nil, or an array of >= 3 {lat:, lng:} vertices in WGS84 range -- rejects
  # garbage before it reaches the json column. Accepts string or symbol keys
  # (controller assigns HashWithIndifferentAccess).
  def property_boundary_shape
    return if property_boundary.nil?

    unless property_boundary.is_a?(Array) &&
           property_boundary.length.between?(3, MAX_PROPERTY_VERTICES)
      return errors.add(:property_boundary, :invalid)
    end

    valid = property_boundary.all? do |point|
      point.is_a?(Hash) &&
        point["lat"].is_a?(Numeric) && point["lat"].between?(-90, 90) &&
        point["lng"].is_a?(Numeric) && point["lng"].between?(-180, 180)
    end
    errors.add(:property_boundary, :invalid) unless valid
  end

  def recompute_property_area
    self.property_area_sqm =
      (Garden::Geometry.polygon_area_sqm(property_boundary) if property?)
  end

  # The custom URLs are handed to the browser to fetch tiles from, so only
  # http(s) may pass -- never javascript:/data: or unparseable input.
  def custom_urls_are_http
    %i[custom_dop_url custom_alkis_url].each do |attr|
      value = self[attr]
      next if value.blank?

      uri = URI.parse(value)
      errors.add(attr, :invalid) unless uri.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      errors.add(attr, :invalid)
    end
  end
end
