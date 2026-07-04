# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Garden::Catalog do
  describe ".sowing_for" do
    it "matches an exact common name" do
      entry = described_class.sowing_for("Tomato")
      expect(entry.key).to eq("tomato")
      expect(entry.sow_from).to eq(3)
      expect(entry.harvest_to).to eq(10)
    end

    it "matches a German alias case/accent-insensitively" do
      expect(described_class.sowing_for("Möhre").key).to eq("carrot")
    end

    it "matches a multi-word name by its crop word (Cherry Tomato -> tomato)" do
      expect(described_class.sowing_for("Cherry Tomato").key).to eq("tomato")
    end

    it "returns nil for an uncatalogued plant" do
      expect(described_class.sowing_for("Dragonfruit")).to be_nil
    end
  end

  describe ".companions" do
    it "returns good and bad neighbours for a crop key" do
      c = described_class.companions("tomato")
      expect(c[:good]).to include("basil")
      expect(c[:bad]).to include("potato")
    end

    it "returns empty lists for an unknown key" do
      expect(described_class.companions("nope")).to eq(good: [], bad: [])
    end
  end
end
