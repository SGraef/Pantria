# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project_status do
    household
    sequence(:name) { |n| "Status #{n}" }
    sequence(:position) { |n| n * 10 }
    done { false }
  end
end
