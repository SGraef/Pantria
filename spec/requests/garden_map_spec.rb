# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "GardenMap" do
  let(:admin)      { create(:user) }
  let!(:household) { create(:household, admin: admin) }

  describe "GET /garden_map" do
    before { login_via_post(admin) }

    it "renders the map with defaults (Niedersachsen, map mode) before any settings exist" do
      create(:garden_bed, household: household, name: "Raised bed A")
      get garden_map_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"garden-map\"")
      expect(response.body).to include("ni_dop20") # LGLN DOP layer in the client config
      expect(response.body).to include("Raised bed A")
    end

    it "renders the lite planner when configured" do
      create(:garden_map_setting, household: household, mode: "lite")
      create(:garden_bed, household: household, width_m: 3, length_m: 1.2)
      get garden_map_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"garden-lite\"")
      expect(response.body).not_to include("data-controller=\"garden-map\"")
    end
  end

  describe "PATCH /garden_map" do
    context "when signed in as an admin" do
      before { login_via_post(admin) }

      it "creates the settings record on first save" do
        expect do
          patch garden_map_path, params: { garden_map_setting: {
            mode: "map", bundesland: "ni", center_lat: 52.37, center_lng: 9.73, zoom: 18
          } }
        end.to change(GardenMapSetting, :count).by(1)
        expect(response).to redirect_to(garden_map_path)
        expect(household.reload.garden_map_setting.zoom).to eq(18)
      end

      it "rejects a non-http custom WMS URL" do
        patch garden_map_path, params: { garden_map_setting: {
          bundesland: "custom", custom_dop_url: "javascript:alert(1)", custom_dop_layer: "x"
        } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(GardenMapSetting.count).to eq(0)
      end
    end

    context "when using the address lookup" do
      before { login_via_post(admin) }

      it "geocodes and saves the viewport" do
        stub_request(:get, %r{nominatim\.openstreetmap\.org/search}).to_return(
          status: 200,
          body:   [{ lat: "52.3705", lon: "9.7332", display_name: "Hannover" }].to_json
        )
        post locate_garden_map_path, params: { address: "Hannah-Arendt-Platz 1, Hannover" }
        expect(response).to redirect_to(garden_map_path)
        settings = household.reload.garden_map_setting
        expect(settings.center_lat.to_f).to eq(52.3705)
        expect(settings.zoom).to eq(GardenMapsController::LOCATE_ZOOM)
        expect(settings.address).to include("Hannah-Arendt-Platz")
      end

      it "reports an unresolvable address without saving" do
        stub_request(:get, %r{nominatim\.openstreetmap\.org/search}).to_return(status: 200, body: "[]")
        post locate_garden_map_path, params: { address: "Nowhere 99" }
        expect(response).to redirect_to(garden_map_path)
        expect(flash[:alert]).to eq(I18n.t("garden_map.locate.not_found"))
      end
    end

    context "when signed in as a non-admin member" do
      let(:member) { create(:user) }

      before do
        create(:membership, user: member, household: household)
        login_via_post(member)
      end

      it "can view the map but not change settings" do
        get garden_map_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("garden_map.settings.heading"))

        patch garden_map_path, params: { garden_map_setting: { mode: "lite" } }
        expect(response).to redirect_to(root_path) # Pundit denial
        expect(GardenMapSetting.count).to eq(0)
      end

      it "cannot use the address lookup" do
        post locate_garden_map_path, params: { address: "Hannover" }
        expect(response).to redirect_to(root_path) # Pundit denial
      end
    end
  end

  describe "GET /garden_map/parcel" do
    let(:gml) { Rails.root.join("spec/fixtures/garden/alkis_flurstueck.xml").read }

    before { login_via_post(admin) }

    it "returns the official parcel at a point as JSON (member-level)" do
      stub_request(:get, /opendata\.lgln\.niedersachsen\.de/).to_return(status: 200, body: gml)
      get parcel_garden_map_path, params: { lat: 52.3705, lng: 9.7332 }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["area_sqm"]).to eq(13_452.0)
      expect(body["boundary"].length).to eq(4)
      expect(body["label"]).to eq("Hannah-Arendt-Platz 1")
    end

    it "404s when no parcel is found" do
      stub_request(:get, /opendata\.lgln\.niedersachsen\.de/).to_return(status: 502)
      get parcel_garden_map_path, params: { lat: 52.3705, lng: 9.7332 }
      expect(response).to have_http_status(:not_found)
    end

    it "422s when the Bundesland has no parcel source" do
      create(:garden_map_setting, household: household, bundesland: "nw")
      get parcel_garden_map_path, params: { lat: 52.3705, lng: 9.7332 }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
