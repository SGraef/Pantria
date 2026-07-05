# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :plant do
    household
    common_name { "Tomato" }

    trait :manual do
      common_name { "Something exotic" }
      perenual_id { nil }
    end
  end
end
