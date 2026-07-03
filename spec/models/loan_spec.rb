# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Loan do
  it "requires an item, counterparty and a valid direction/status" do
    loan = described_class.new(household: build(:household))
    expect(loan).not_to be_valid
    expect(loan.errors.attribute_names).to include(:item, :counterparty)

    loan.assign_attributes(item: "Drill", counterparty: "Anna", direction: "sideways", status: "pending")
    expect(loan).not_to be_valid
    expect(loan.errors.attribute_names).to include(:direction, :status)
  end

  it "derives a transliterated, downcased counterparty_key before validation" do
    loan = create(:loan, counterparty: "Anna Müller")
    expect(loan.counterparty_key).to eq("anna muller")
  end

  describe "#mark_returned! / #reopen!" do
    it "flips status and stamps returned_on" do
      loan = create(:loan)
      loan.mark_returned!
      expect(loan).to be_returned
      expect(loan.returned_on).to eq(Date.current)

      loan.reopen!
      expect(loan).not_to be_returned
      expect(loan.returned_on).to be_nil
    end
  end

  describe "photo attachment" do
    it "accepts an image" do
      loan = build(:loan)
      loan.photo.attach(io: StringIO.new("fake"), filename: "drill.jpg", content_type: "image/jpeg")
      expect(loan).to be_valid
    end

    it "rejects a non-image file" do
      loan = build(:loan)
      loan.photo.attach(io: StringIO.new("%PDF-1.4"), filename: "drill.pdf", content_type: "application/pdf")
      expect(loan).not_to be_valid
      expect(loan.errors.attribute_names).to include(:photo)
    end

    it "is valid without a photo" do
      expect(build(:loan)).to be_valid
    end
  end

  describe "scopes" do
    it "separates outstanding/returned and borrowed/lent" do
      borrowed = create(:loan)
      lent     = create(:loan, :lent)
      done     = create(:loan, :returned)

      expect(described_class.outstanding).to contain_exactly(borrowed, lent)
      expect(described_class.returned).to contain_exactly(done)
      expect(described_class.borrowed).to include(borrowed)
      expect(described_class.lent).to contain_exactly(lent)
    end
  end
end
