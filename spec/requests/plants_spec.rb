# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "Plants" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  describe "GET /plants" do
    it "lists the catalog with sow/harvest windows" do
      create(:plant, household: household, common_name: "Tomato")
      get plants_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tomato")
    end
  end

  describe "GET /plants/search" do
    it "prompts to connect Perenual when no key is set" do
      get search_plants_path(q: "tomato")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("plant.connect_first"))
    end

    it "shows importable results when connected" do
      create(:garden_connection, household: household, api_key: "k")
      stub_request(:get, "https://perenual.com/api/v2/species-list")
        .with(query: hash_including(q: "tomato", key: "k"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          data: [{ id: 1, common_name: "Garden Tomato", scientific_name: ["Solanum lycopersicum"], cycle: "Annual" }]
        }.to_json)

      get search_plants_path(q: "tomato")
      expect(response.body).to include("Garden Tomato")
    end
  end

  describe "POST /plants/import" do
    it "imports a species, fetching care details and applying catalog defaults" do
      create(:garden_connection, household: household, api_key: "k")
      stub_request(:get, "https://perenual.com/api/v2/species/details/1")
        .with(query: hash_including(key: "k"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          id: 1, common_name: "Tomato", scientific_name: ["Solanum lycopersicum"],
          cycle: "Annual", sunlight: ["full_sun"], watering: "Average",
          hardiness: { min: "2", max: "11" }, edible_fruit: true
        }.to_json)

      expect do
        post import_plants_path, params: { perenual_id: 1, common_name: "Tomato" }
      end.to change(Plant, :count).by(1)

      plant = Plant.last
      expect(plant.sow_from_month).to eq(3)     # from curated calendar
      expect(plant.hardiness_min).to eq(2)      # from Perenual
      expect(response).to redirect_to(plant_path(plant))
    end

    it "still imports basic data when the details call fails" do
      create(:garden_connection, household: household, api_key: "k")
      stub_request(:get, "https://perenual.com/api/v2/species/details/2")
        .with(query: hash_including(key: "k"))
        .to_return(status: 429, body: "slow down")

      expect do
        post import_plants_path, params: { perenual_id: 2, common_name: "Basil" }
      end.to change(Plant, :count).by(1)
      expect(Plant.last.common_name).to eq("Basil")
    end
  end

  describe "GET /plants/:id" do
    it "shows a plant with its companion planting" do
      plant = create(:plant, household: household, common_name: "Tomato")
      get plant_path(plant)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("garden.crops.basil")) # good neighbour
    end
  end

  describe "DELETE /plants/:id" do
    it "removes a plant" do
      plant = create(:plant, household: household)
      expect { delete plant_path(plant) }.to change(Plant, :count).by(-1)
    end
  end
end
