# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project_relation do
    project
    related_project { create(:project, household: project.household) }
    kind { "related" }
  end
end
