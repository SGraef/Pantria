# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Planting do
  it "validates status and a positive quantity" do
    planting = build(:planting, status: "bogus", quantity: 0)
    expect(planting).not_to be_valid
    expect(planting.errors.attribute_names).to include(:status, :quantity)
  end

  it "delegates plant traits (name, sow window) to its plant" do
    plant = create(:plant, common_name: "Tomato")
    planting = create(:planting, plant: plant)
    expect(planting.common_name).to eq("Tomato")
    expect(planting.sow_from_month).to eq(3)
  end

  describe "lifecycle predicates" do
    it "flags a planned planting as awaiting sowing" do
      expect(build(:planting, status: "planned").awaiting_sowing?).to be(true)
    end

    it "flags a sown/growing planting as growing" do
      expect(build(:planting, status: "sown").growing?).to be(true)
      expect(build(:planting, status: "growing").growing?).to be(true)
      expect(build(:planting, status: "harvested").growing?).to be(false)
    end
  end

  describe "scopes" do
    it "excludes harvested plantings from .active" do
      a = create(:planting, status: "growing")
      create(:planting, status: "harvested")
      expect(described_class.active).to contain_exactly(a)
    end
  end
end
