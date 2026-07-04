# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe GardenBed do
  let(:household) { create(:household) }

  # Small triangle near Hannover, roughly 10 m x 10 m right angle => ~50 m2.
  let(:triangle) do
    step = 10.0 / Garden::Geometry::EARTH_RADIUS_M * 180 / Math::PI
    [{ "lat" => 52.0, "lng" => 9.0 },
     { "lat" => 52.0, "lng" => 9.0 + (step / Math.cos(52 * Math::PI / 180)) },
     { "lat" => 52.0 + step, "lng" => 9.0 }]
  end

  describe "boundary validation" do
    it "accepts nil and a valid ring" do
      expect(build(:garden_bed, household:)).to be_valid
      expect(build(:garden_bed, household:, boundary: triangle)).to be_valid
    end

    it "rejects non-arrays, short rings, and out-of-range vertices" do
      expect(build(:garden_bed, household:, boundary: "poly")).not_to be_valid
      expect(build(:garden_bed, household:, boundary: triangle.first(2))).not_to be_valid
      bad_vertex = triangle[0..1] + [{ "lat" => 999, "lng" => 9.0 }]
      expect(build(:garden_bed, household:, boundary: bad_vertex)).not_to be_valid
      missing_key = triangle[0..1] + [{ "lat" => 52.0 }]
      expect(build(:garden_bed, household:, boundary: missing_key)).not_to be_valid
    end

    it "caps the vertex count" do
      huge = Array.new(GardenBed::MAX_BOUNDARY_VERTICES + 1) { |i| { "lat" => 52.0, "lng" => 9.0 + (i * 1e-6) } }
      expect(build(:garden_bed, household:, boundary: huge)).not_to be_valid
    end
  end

  describe "dimension validation" do
    it "rejects non-positive or absurd sizes" do
      expect(build(:garden_bed, household:, width_m: 0)).not_to be_valid
      expect(build(:garden_bed, household:, length_m: -1)).not_to be_valid
      expect(build(:garden_bed, household:, width_m: 1001)).not_to be_valid
      expect(build(:garden_bed, household:, pos_x_m: -0.5)).not_to be_valid
    end
  end

  describe "#recompute_area" do
    it "computes area from the boundary" do
      bed = create(:garden_bed, household:, boundary: triangle)
      expect(bed.area_sqm).to be_within(1).of(50.0)
    end

    it "falls back to width * length" do
      bed = create(:garden_bed, household:, width_m: 3.0, length_m: 1.2)
      expect(bed.area_sqm).to eq(3.6)
    end

    it "prefers the boundary when both are present" do
      bed = create(:garden_bed, household:, boundary: triangle, width_m: 2, length_m: 2)
      expect(bed.area_sqm).to be_within(1).of(50.0)
    end

    it "clears the area when geometry is removed" do
      bed = create(:garden_bed, household:, width_m: 2, length_m: 2)
      bed.update!(width_m: nil)
      expect(bed.area_sqm).to be_nil
    end
  end
end
