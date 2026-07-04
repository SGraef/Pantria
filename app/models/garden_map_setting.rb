# frozen_string_literal: true
# typed: false

# Per-household garden map configuration: mode (Leaflet map over official WMS
# layers, or the abstract "lite" planner for regions without an open WMS),
# the Bundesland whose geodata services to use (see {Garden::MapSources}),
# the saved viewport, and custom WMS fields for unlisted states.
#
# Deliberately separate from {GardenConnection} (the Perenual API binding):
# the map works without any Perenual key. Admin-only to edit -- the custom
# URLs end up in every member's browser -- but visible to all members.
class GardenMapSetting < ApplicationRecord
  belongs_to :household

  MODES = %w[map lite].freeze

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

  def map_mode?  = mode == "map"
  def lite_mode? = mode == "lite"

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
