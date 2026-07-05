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

  # Candidate parents for a project: every household project except itself
  # and its own subtree (nesting must stay acyclic).
  # @return [Array<Project>]
  def parent_project_options(project)
    all = project.household.projects.ordered.to_a
    return all unless project.persisted?

    by_parent = all.group_by(&:parent_id)
    excluded = [project.id]
    queue = [project.id]
    while (id = queue.shift)
      by_parent.fetch(id, []).each do |child|
        excluded << child.id
        queue << child.id
      end
    end
    all.reject { |p| excluded.include?(p.id) }
  end

  # "1.234,56 €" style money for a cents value (project currency is EUR by
  # default; number_to_currency handles the locale).
  # @return [String]
  def project_money(cents)
    number_to_currency((cents || 0) / 100.0)
  end
end
