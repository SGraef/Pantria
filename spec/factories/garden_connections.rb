# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :garden_connection do
    household
    api_key { "perenual-test-key" }
    hardiness_zone { "7" }
  end
end
