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

  describe "PATCH /garden_beds/:id/geometry" do
    let(:bed) { create(:garden_bed, household: household) }
    # Roughly 10 m x 10 m right triangle near Hannover => ~50 m2.
    let(:ring) do
      step = 10.0 / Garden::Geometry::EARTH_RADIUS_M * 180 / Math::PI
      [{ lat: 52.0, lng: 9.0 },
       { lat: 52.0, lng: 9.0 + (step / Math.cos(52 * Math::PI / 180)) },
       { lat: 52.0 + step, lng: 9.0 }]
    end

    it "saves a traced boundary and returns the server-computed measurements" do
      patch geometry_garden_bed_path(bed), params: { garden_bed: { boundary: ring } }, as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["area_sqm"]).to be_within(1).of(50.0)
      expect(body["edges_m"].length).to eq(3)
      expect(bed.reload.boundary.length).to eq(3)
    end

    it "clears the boundary with an empty array" do
      bed.update!(boundary: ring.map { |p| p.transform_keys(&:to_s) })
      patch geometry_garden_bed_path(bed), params: { garden_bed: { boundary: [] } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(bed.reload.boundary).to be_nil
      expect(bed.area_sqm).to be_nil
    end

    it "saves lite-planner dimensions and position" do
      patch geometry_garden_bed_path(bed),
            params: { garden_bed: { width_m: 3.0, length_m: 1.2, pos_x_m: 2.5, pos_y_m: 0 } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["area_sqm"]).to eq(3.6)
      expect(bed.reload.pos_x_m).to eq(2.5)
    end

    it "rejects an invalid boundary" do
      patch geometry_garden_bed_path(bed),
            params: { garden_bed: { boundary: [{ lat: 999, lng: 9 }, { lat: 52, lng: 9 }, { lat: 52, lng: 10 }] } },
            as:     :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(bed.reload.boundary).to be_nil
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
