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
end
