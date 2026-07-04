# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Garden::Geometry do
  # A ~10m x 10m square at lat 52 deg (Niedersachsen): 10 m north-south is
  # ~8.983e-5 deg lat; 10 m east-west at that latitude is lng delta
  # 10 / (R * cos(52 deg)) in radians.
  let(:lat_step) { 10.0 / described_class::EARTH_RADIUS_M * 180 / Math::PI }
  let(:lng_step) { lat_step / Math.cos(52 * Math::PI / 180) }
  let(:square) do
    [{ "lat" => 52.0, "lng" => 9.0 },
     { "lat" => 52.0, "lng" => 9.0 + lng_step },
     { "lat" => 52.0 + lat_step, "lng" => 9.0 + lng_step },
     { "lat" => 52.0 + lat_step, "lng" => 9.0 }]
  end

  describe ".polygon_area_sqm" do
    it "measures a 10 m square within 0.5 percent" do
      expect(described_class.polygon_area_sqm(square)).to be_within(0.5).of(100.0)
    end

    it "is orientation-independent (clockwise ring)" do
      expect(described_class.polygon_area_sqm(square.reverse)).to be_within(0.5).of(100.0)
    end

    it "returns 0.0 for degenerate rings" do
      expect(described_class.polygon_area_sqm([])).to eq(0.0)
      expect(described_class.polygon_area_sqm(square.first(2))).to eq(0.0)
      expect(described_class.polygon_area_sqm(nil)).to eq(0.0)
    end

    it "accepts symbol keys" do
      ring = square.map { |p| { lat: p["lat"], lng: p["lng"] } }
      expect(described_class.polygon_area_sqm(ring)).to be_within(0.5).of(100.0)
    end
  end

  describe ".edge_lengths_m" do
    it "returns all four ~10 m edges including the closing one" do
      lengths = described_class.edge_lengths_m(square)
      expect(lengths.length).to eq(4)
      expect(lengths).to all(be_within(0.05).of(10.0))
    end

    it "returns [] for fewer than two points" do
      expect(described_class.edge_lengths_m([square.first])).to eq([])
    end
  end
end
