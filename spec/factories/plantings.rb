# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :planting do
    household
    garden_bed { association :garden_bed, household: household }
    plant { association :plant, household: household }
    quantity { 1 }
    status { "planned" }
  end
end
