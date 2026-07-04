# frozen_string_literal: true
# typed: false

module GardenHelper
  # Render a month window (1-12) as localized abbreviated names, e.g. "Mar–Apr".
  # A single month renders alone; nil bounds render an em dash.
  # @return [String]
  def garden_month_range(from, to)
    return "—" if from.blank? || to.blank?

    names = I18n.t("date.abbr_month_names")
    from == to ? names[from] : "#{names[from]}–#{names[to]}"
  end

  # Localized crop label for a companion key (falls back to the humanized key).
  # @return [String]
  def garden_crop_label(key)
    t("garden.crops.#{key}", default: key.to_s.humanize)
  end

  # Label for the one-tap "advance" button given a planting's current status,
  # or nil once harvested (nothing left to advance to).
  # @return [String, nil]
  def planting_advance_label(planting)
    case planting.status
    when "planned" then t("planting.advance.to_sown")
    when "sown"    then t("planting.advance.to_growing")
    when "growing" then t("planting.advance.to_harvested")
    end
  end

  # Bad-neighbour conflicts within a bed: for each active planting, the other
  # crop keys present that its companion table warns against.
  # @param plantings [Enumerable<Planting>]
  # @return [Hash{Planting=>Array<String>}] only plantings with a conflict.
  def companion_conflicts_for(plantings)
    active = plantings.reject { |p| p.status == "harvested" }
    present = active.map(&:crop_key).compact
    active.each_with_object({}) do |planting, out|
      next if planting.crop_key.blank?

      bad = (planting.plant&.companions&.dig(:bad) || []) & present
      out[planting] = bad if bad.any?
    end
  end
end
