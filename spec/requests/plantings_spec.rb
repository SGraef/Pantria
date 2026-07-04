# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "Plantings" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }
  let(:bed)        { create(:garden_bed, household: household) }
  let(:plant)      { create(:plant, household: household, common_name: "Tomato") }

  before { login_via_post(user) }

  describe "POST /plantings" do
    it "adds a plant to a bed" do
      expect do
        post plantings_path, params: { planting: { garden_bed_id: bed.id, plant_id: plant.id, quantity: 4 } }
      end.to change(Planting, :count).by(1)
      expect(response).to redirect_to(garden_bed_path(bed))
      expect(Planting.last.quantity).to eq(4)
    end
  end

  describe "POST /plantings/:id/advance" do
    it "walks the lifecycle and stamps dates" do
      planting = create(:planting, household: household, garden_bed: bed, plant: plant, status: "planned")

      post advance_planting_path(planting)
      expect(planting.reload.status).to eq("sown")
      expect(planting.sown_on).to eq(Date.current)

      post advance_planting_path(planting)
      expect(planting.reload.status).to eq("growing")

      post advance_planting_path(planting)
      expect(planting.reload.status).to eq("harvested")
      expect(planting.harvested_on).to eq(Date.current)
    end
  end

  describe "DELETE /plantings/:id" do
    it "removes a planting" do
      planting = create(:planting, household: household, garden_bed: bed, plant: plant)
      expect { delete planting_path(planting) }.to change(Planting, :count).by(-1)
    end
  end
end
