# frozen_string_literal: true
# typed: true

# Seeds a household's project statuses (= kanban columns). Runs:
#
#   * on Household creation (after_create)
#   * lazily from ProjectsController -- backfills households that existed
#     before the projects feature shipped
#   * via the "Reset to defaults" button on /projects/statuses
#
# Idempotent like {OfferCategorySeeder}: the default (`replace: false`)
# only seeds when the household has no statuses yet. Defaults are inline
# (four rows, no per-row payload) rather than YAML.
class ProjectStatusSeeder
  DEFAULTS = [
    { name: "Idee",      color: "sand", done: false },
    { name: "Geplant",   color: "sky",  done: false },
    { name: "In Arbeit", color: "clay", done: false },
    { name: "Erledigt",  color: "olive", done: true }
  ].freeze

  # @param household [Household]
  # @param replace [Boolean] when true, drop existing statuses first --
  #   callers must ensure no project still points at them
  # @return [Integer] number of statuses seeded
  def self.call(household, replace: false)
    return 0 if !replace && household.project_statuses.exists?

    ProjectStatus.transaction do
      household.project_statuses.destroy_all if replace

      DEFAULTS.each_with_index do |attrs, i|
        household.project_statuses.create!(attrs.merge(position: (i + 1) * 10))
      end
    end

    DEFAULTS.size
  end
end
