# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project_category do
    household
    sequence(:name) { |n| "Category #{n}" }
    sequence(:position) { |n| n * 10 }
  end
end
