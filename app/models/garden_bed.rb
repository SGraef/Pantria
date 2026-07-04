# frozen_string_literal: true
# typed: false

# A plot in the garden (raised bed, row, balcony box). Holds {Planting}s so the
# planner can show what's growing where.
class GardenBed < ApplicationRecord
  SUN_EXPOSURES = %w[full_sun part_shade full_shade].freeze

  belongs_to :household
  has_many :plantings, dependent: :destroy
  has_many :plants, through: :plantings

  validates :name, presence: true, length: { maximum: 120 }
  validates :sun_exposure, inclusion: { in: SUN_EXPOSURES }, allow_blank: true

  scope :ordered, -> { order(:name) }

  # Plantings still in the ground (anything not yet harvested).
  def active_plantings
    plantings.where.not(status: "harvested")
  end
end
