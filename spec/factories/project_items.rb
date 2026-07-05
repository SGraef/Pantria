# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :project_item do
    project
    kind { "material" }
    sequence(:name) { |n| "Item #{n}" }

    trait(:plan) { kind { "plan" } }

    trait :with_file do
      after(:build) do |item|
        item.file.attach(
          io:           StringIO.new("%PDF-1.4 fake"),
          filename:     "plan.pdf",
          content_type: "application/pdf"
        )
      end
    end
  end
end
