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
    end
  end
end
