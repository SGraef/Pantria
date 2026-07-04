# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Garden::MapSources do
  describe "KEYS" do
    it "lists the registered Bundesland codes without custom" do
      expect(described_class::KEYS).to include("ni", "nw")
      expect(described_class::KEYS).not_to include("custom")
    end
  end

  describe "registry entries" do
    it "ships verified DOP and ALKIS sources for Niedersachsen" do
      ni = described_class.fetch("ni")
      expect(ni[:dop][:url]).to include("lgln.niedersachsen.de")
      expect(ni[:alkis][:layer]).to eq("ALKIS")
    end

    it "ships NRW without an ALKIS layer (unverified)" do
      expect(described_class.fetch("nw")[:alkis]).to be_nil
    end
  end

  describe ".client_config" do
    it "resolves a registry state" do
      setting = build(:garden_map_setting, bundesland: "ni")
      config = described_class.client_config(setting)
      expect(config[:basemap][:url]).to eq(described_class::BASEMAP[:url])
      expect(config[:dop][:layer]).to eq("ni_dop20")
      expect(config[:alkis][:layer]).to eq("ALKIS")
    end

    it "resolves custom WMS fields, dropping half-configured layers" do
      setting = build(:garden_map_setting, bundesland:         "custom",
                                           custom_dop_url:     "https://wms.example.de/dop",
                                           custom_dop_layer:   "dop_rgb",
                                           custom_alkis_url:   "https://wms.example.de/alkis",
                                           custom_alkis_layer: nil)
      config = described_class.client_config(setting)
      expect(config[:dop]).to eq(url: "https://wms.example.de/dop", layer: "dop_rgb", attribution: nil)
      expect(config[:alkis]).to be_nil
      expect(config[:basemap]).to eq(described_class::BASEMAP)
    end

    it "returns only the basemap for an unknown state" do
      setting = build(:garden_map_setting)
      setting.bundesland = "xx"
      config = described_class.client_config(setting)
      expect(config[:dop]).to be_nil
      expect(config[:alkis]).to be_nil
    end
  end

  describe ".options_for_select" do
    it "offers all states plus the custom escape hatch" do
      options = described_class.options_for_select
      expect(options).to include(%w[Niedersachsen ni])
      expect(options.last.last).to eq("custom")
    end
  end
end
