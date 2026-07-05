# frozen_string_literal: true
# typed: false

# A plant placed in a bed -- the concrete "4 tomatoes in Bed 1" record. Its
# status and the plant's sow/harvest windows drive the garden reminders
# (Reminders::GardenScanner).
class Planting < ApplicationRecord
  STATUSES = %w[planned sown growing harvested].freeze

  belongs_to :household
  belongs_to :garden_bed
  belongs_to :plant

  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  delegate :common_name, :crop_key, :sow_from_month, :sow_to_month,
           :harvest_from_month, :harvest_to_month, :sow_month?, :harvest_month?,
           to: :plant, allow_nil: true

  scope :active, -> { where.not(status: "harvested") }
  scope :ordered, -> { order(created_at: :desc) }

  # @return [Boolean] not yet sown -- eligible for a "time to sow" reminder.
  def awaiting_sowing?
    status == "planned"
  end

  # @return [Boolean] in the ground -- eligible for a "harvest now" reminder.
  def growing?
    status.in?(%w[sown growing])
  end
end
