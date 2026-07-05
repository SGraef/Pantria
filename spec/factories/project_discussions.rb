# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project_discussion do
    project
    sequence(:title) { |n| "Discussion #{n}" }
    status { "open" }
  end
end
