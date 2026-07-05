# frozen_string_literal: true
# typed: false

module ProjectsHelper
  # Options for the shared color <select> on status/category settings.
  # @return [Array<Array(String, String)>]
  def project_color_options
    [[t("common.colors.none"), ""]] +
      ColorPalette::COLORS.map { |c| [t("common.colors.#{c}"), c] }
  end

  # A palette-colored chip; neutral .chip when no color is set.
  # @return [String]
  def color_chip(text, color)
    css = color.present? ? "chip chip-color-#{color}" : "chip"
    tag.span(text, class: css)
  end
end
