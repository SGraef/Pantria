# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Perenual::Client do
  let(:connection) { build(:garden_connection, api_key: "test-key") }
  let(:client)     { described_class.new(connection) }

  describe "#search" do
    it "maps species-list results to summaries" do
      stub_request(:get, "https://perenual.com/api/v2/species-list")
        .with(query: hash_including(q: "tomato", key: "test-key"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          data: [
            { id: 1, common_name: "Garden Tomato",
              scientific_name: ["Solanum lycopersicum"], cycle: "Annual",
              default_image: { regular_url: "https://img/tomato.jpg" } }
          ]
        }.to_json)

      results = client.search("tomato")
      expect(results.size).to eq(1)
      expect(results.first.perenual_id).to eq(1)
      expect(results.first.common_name).to eq("Garden Tomato")
      expect(results.first.scientific_name).to eq("Solanum lycopersicum")
      expect(results.first.image_url).to eq("https://img/tomato.jpg")
    end

    it "raises AuthError on a rejected key" do
      stub_request(:get, "https://perenual.com/api/v2/species-list")
        .with(query: hash_including(key: "test-key"))
        .to_return(status: 401, body: "nope")
      expect { client.search("x") }.to raise_error(Perenual::AuthError)
    end

    it "raises RateLimitError on HTTP 429" do
      stub_request(:get, "https://perenual.com/api/v2/species-list")
        .with(query: hash_including(key: "test-key"))
        .to_return(status: 429, body: "slow down")
      expect { client.search("x") }.to raise_error(Perenual::RateLimitError)
    end

    it "raises AuthError when no key is configured" do
      c = described_class.new(build(:garden_connection, api_key: nil))
      expect { c.search("x") }.to raise_error(Perenual::AuthError)
    end
  end

  describe "#details" do
    it "maps a species detail into care fields" do
      stub_request(:get, "https://perenual.com/api/v2/species/details/1")
        .with(query: hash_including(key: "test-key"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          id: 1, common_name: "Garden Tomato", scientific_name: ["Solanum lycopersicum"],
          cycle: "Annual", sunlight: ["full_sun"], watering: "Average",
          hardiness: { min: "2", max: "11" }, edible_fruit: true,
          default_image: { regular_url: "https://img/tomato.jpg" }
        }.to_json)

      d = client.details(1)
      expect(d.cycle).to eq("Annual")
      expect(d.sunlight).to eq("full_sun")
      expect(d.hardiness_min).to eq(2)
      expect(d.hardiness_max).to eq(11)
      expect(d.edible).to be(true)
      expect(d.external_url).to include("perenual.com")
    end
  end
end
