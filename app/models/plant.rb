# frozen_string_literal: true
# typed: false

# A plant in the household catalog. Either imported from Perenual (perenual_id
# set, care fields cached) or hand-added. On save we derive the crop_key and, if
# the gardener hasn't set them, the sow/harvest months from the curated
# {Garden::Catalog} -- so a freshly imported "Tomato" already knows it's sown
# Mar-Apr and harvested Jul-Oct.
class Plant < ApplicationRecord
  belongs_to :household

  validates :common_name, presence: true, length: { maximum: 200 }
  validates :sow_from_month, :sow_to_month, :harvest_from_month, :harvest_to_month,
            inclusion: { in: 1..12 }, allow_nil: true

  before_validation :apply_catalog_defaults

  scope :ordered, -> { order(:common_name) }
  scope :edible,  -> { where(edible: true) }

  # Companion planting for this plant, from the curated table.
  # @return [Hash{Symbol=>Array<String>}] { good: [...], bad: [...] }
  def companions
    Garden::Catalog.companions(crop_key)
  end

  # @return [Boolean] whether the given month (1-12) is within the sow window,
  #   handling windows that wrap the year end (e.g. garlic Oct-Nov, kale Oct-Feb).
  def sow_month?(month)
    within_window?(month, sow_from_month, sow_to_month)
  end

  def harvest_month?(month)
    within_window?(month, harvest_from_month, harvest_to_month)
  end

  private

  def apply_catalog_defaults
    self.crop_key = Garden::Catalog.crop_key_for(common_name) if crop_key.blank?
    return unless (entry = Garden::Catalog.sowing_for(common_name))

    self.sow_from_month     ||= entry.sow_from
    self.sow_to_month       ||= entry.sow_to
    self.harvest_from_month ||= entry.harvest_from
    self.harvest_to_month   ||= entry.harvest_to
  end

  def within_window?(month, from, to)
    return false if month.blank? || from.blank? || to.blank?

    from <= to ? month.between?(from, to) : (month >= from || month <= to)
  end
end
