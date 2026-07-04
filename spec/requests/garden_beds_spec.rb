# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "GardenBeds" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  describe "GET /garden_beds" do
    it "lists beds with their active planting count" do
      create(:garden_bed, household: household, name: "Raised bed A")
      get garden_beds_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Raised bed A")
    end
  end

  describe "POST /garden_beds" do
    it "creates a bed" do
      expect do
        post garden_beds_path, params: { garden_bed: { name: "Herb spiral", sun_exposure: "part_shade" } }
      end.to change(GardenBed, :count).by(1)
      expect(response).to redirect_to(garden_bed_path(GardenBed.last))
    end

    it "rejects an invalid sun exposure" do
      post garden_beds_path, params: { garden_bed: { name: "X", sun_exposure: "moon" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /garden_beds/:id" do
    it "shows the bed, its plantings and companion conflicts" do
      bed = create(:garden_bed, household: household)
      tomato = create(:plant, household: household, common_name: "Tomato")
      potato = create(:plant, household: household, common_name: "Potato")
      create(:planting, household: household, garden_bed: bed, plant: tomato, status: "growing")
      create(:planting, household: household, garden_bed: bed, plant: potato, status: "growing")

      get garden_bed_path(bed)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tomato")
      # tomato + potato are antagonists -> conflict warning is rendered
      expect(response.body).to include(I18n.t("garden_bed.conflicts_heading"))
    end
  end

  describe "DELETE /garden_beds/:id" do
    it "removes the bed and its plantings" do
      bed = create(:garden_bed, household: household)
      create(:planting, household: household, garden_bed: bed)
      expect { delete garden_bed_path(bed) }.to change(GardenBed, :count).by(-1)
                                                                         .and change(Planting, :count).by(-1)
    end
  end
end
