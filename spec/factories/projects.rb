# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project do
    household
    sequence(:name) { |n| "Project #{n}" }
    # Households auto-seed four default statuses on create; fall back to an
    # explicit one for edge cases that wiped them.
    project_status do
      household.project_statuses.ordered.first ||
        create(:project_status, household: household)
    end
  end
end
