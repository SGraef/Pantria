# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :garden_map_setting do
    household
    mode { "map" }
    bundesland { "ni" }
  end
end
