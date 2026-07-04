# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Plant do
  it "requires a common name" do
    plant = described_class.new(household: build(:household))
    expect(plant).not_to be_valid
    expect(plant.errors.attribute_names).to include(:common_name)
  end

  describe "catalog defaults" do
    it "derives crop_key and sow/harvest months from the curated calendar" do
      plant = create(:plant, common_name: "Tomato")
      expect(plant.crop_key).to eq("tomato")
      expect(plant.sow_from_month).to eq(3)
      expect(plant.sow_to_month).to eq(4)
      expect(plant.harvest_from_month).to eq(7)
      expect(plant.harvest_to_month).to eq(10)
    end

    it "does not override months the gardener set explicitly" do
      plant = create(:plant, common_name: "Tomato", sow_from_month: 2)
      expect(plant.sow_from_month).to eq(2)
    end

    it "leaves months nil for an uncatalogued plant" do
      plant = create(:plant, :manual)
      expect(plant.crop_key).to be_nil
      expect(plant.sow_from_month).to be_nil
    end
  end

  describe "#companions" do
    it "exposes the curated companion table" do
      plant = create(:plant, common_name: "Tomato")
      expect(plant.companions[:good]).to include("basil")
      expect(plant.companions[:bad]).to include("potato")
    end
  end

  describe "sow/harvest month membership" do
    it "handles windows that wrap the year end (garlic Oct-Nov)" do
      plant = create(:plant, common_name: "Garlic")
      expect(plant.sow_month?(10)).to be(true)
      expect(plant.sow_month?(11)).to be(true)
      expect(plant.sow_month?(5)).to be(false)
    end

    it "handles a normal in-year window (kale harvest Oct-Feb)" do
      plant = create(:plant, common_name: "Kale")
      expect(plant.harvest_month?(1)).to be(true)
      expect(plant.harvest_month?(11)).to be(true)
      expect(plant.harvest_month?(6)).to be(false)
    end
  end
end
