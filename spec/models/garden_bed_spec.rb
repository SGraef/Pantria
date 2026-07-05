# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe GardenBed do
  let(:household) { create(:household) }

  describe "dimension validation" do
    it "rejects non-positive or absurd sizes" do
      expect(build(:garden_bed, household:, width_m: 0)).not_to be_valid
      expect(build(:garden_bed, household:, length_m: -1)).not_to be_valid
      expect(build(:garden_bed, household:, width_m: 1001)).not_to be_valid
      expect(build(:garden_bed, household:, pos_x_m: -0.5)).not_to be_valid
    end
  end

  describe "#recompute_area" do
    it "computes the area from width * length" do
      bed = create(:garden_bed, household:, width_m: 3.0, length_m: 1.2)
      expect(bed.area_sqm).to eq(3.6)
      expect(bed).to be_sized
    end

    it "clears the area when a dimension is removed" do
      bed = create(:garden_bed, household:, width_m: 2, length_m: 2)
      bed.update!(width_m: nil)
      expect(bed.area_sqm).to be_nil
      expect(bed).not_to be_sized
    end
  end
end
