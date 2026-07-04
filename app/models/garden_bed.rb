# frozen_string_literal: true
# typed: false

# A plot in the garden (raised bed, row, balcony box). Holds {Planting}s so the
# planner can show what's growing where.
#
# Geometry: `boundary` is a polygon traced on the garden map (WGS84 ring,
# [{lat:, lng:}, ...]); `width_m`/`length_m` + `pos_x_m`/`pos_y_m` place the
# bed on the lite planner's abstract canvas. Both can coexist (a household
# that switched modes keeps the other mode's data); the denormalized
# `area_sqm` prefers the traced boundary over width*length.
class GardenBed < ApplicationRecord
  SUN_EXPOSURES = %w[full_sun part_shade full_shade].freeze

  MAX_BOUNDARY_VERTICES = 100

  belongs_to :household
  has_many :plantings, dependent: :destroy
  has_many :plants, through: :plantings

  validates :name, presence: true, length: { maximum: 120 }
  validates :sun_exposure, inclusion: { in: SUN_EXPOSURES }, allow_blank: true
  validates :width_m, :length_m,
            numericality: { greater_than: 0, less_than_or_equal_to: 1000 }, allow_nil: true
  validates :pos_x_m, :pos_y_m,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :boundary_shape

  before_save :recompute_area

  scope :ordered, -> { order(:name) }

  # @return [Boolean] true when a polygon was traced on the map
  def mapped? = boundary.present?

  # @return [Boolean] true when lite-mode dimensions are set
  def sized? = width_m.present? && length_m.present?

  # Plantings still in the ground (anything not yet harvested).
  def active_plantings
    plantings.where.not(status: "harvested")
  end

  private

  # nil, or an array of >= 3 {lat:, lng:} vertices in WGS84 range. Rejects
  # anything else so garbage from the geometry endpoint never reaches the
  # json column.
  def boundary_shape
    return if boundary.nil?

    unless boundary.is_a?(Array) && boundary.length.between?(3, MAX_BOUNDARY_VERTICES)
      return errors.add(:boundary, :invalid)
    end

    valid = boundary.all? do |point|
      point.is_a?(Hash) &&
        point["lat"].is_a?(Numeric) && point["lat"].between?(-90, 90) &&
        point["lng"].is_a?(Numeric) && point["lng"].between?(-180, 180)
    end
    errors.add(:boundary, :invalid) unless valid
  end

  def recompute_area
    self.area_sqm =
      if boundary.present?
        Garden::Geometry.polygon_area_sqm(boundary)
      elsif sized?
        (width_m * length_m).round(2)
      end
  end
end
