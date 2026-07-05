# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :garden_bed do
    household
    sequence(:name) { |n| "Bed #{n}" }
    sun_exposure { "full_sun" }
  end
end
