# frozen_string_literal: true
# typed: false

# A plot in the garden (raised bed, row, balcony box). Holds {Planting}s so the
# planner can show what's growing where.
#
# Geometry: `width_m`/`length_m` size the bed, `pos_x_m`/`pos_y_m` place it on
# the to-scale garden planner (inside the Grundstück outline captured on the
# garden map -- see {GardenMapSetting#property_boundary}). Beds carry no geo
# coordinates themselves; `area_sqm` is denormalized from width * length.
class GardenBed < ApplicationRecord
  SUN_EXPOSURES = %w[full_sun part_shade full_shade].freeze

  belongs_to :household
  has_many :plantings, dependent: :destroy
  has_many :plants, through: :plantings

  validates :name, presence: true, length: { maximum: 120 }
  validates :sun_exposure, inclusion: { in: SUN_EXPOSURES }, allow_blank: true
  validates :width_m, :length_m,
            numericality: { greater_than: 0, less_than_or_equal_to: 1000 }, allow_nil: true
  validates :pos_x_m, :pos_y_m,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :recompute_area

  scope :ordered, -> { order(:name) }

  # @return [Boolean] true when planner dimensions are set
  def sized? = width_m.present? && length_m.present?

  # Plantings still in the ground (anything not yet harvested).
  def active_plantings
    plantings.where.not(status: "harvested")
  end

  private

  def recompute_area
    self.area_sqm = ((width_m * length_m).round(2) if sized?)
  end
end
