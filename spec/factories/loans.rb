# frozen_string_literal: true
# typed: false

FactoryBot.define do
  factory :loan do
    household
    sequence(:item) { |n| "Item #{n}" }
    counterparty    { "Anna Müller" }
    direction       { "borrowed" }
    status          { "outstanding" }
    loaned_on       { Date.new(2026, 6, 1) }

    trait :lent do
      direction { "lent" }
    end

    trait :returned do
      status      { "returned" }
      returned_on { Date.new(2026, 6, 10) }
    end
  end
end
