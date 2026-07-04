# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe GardenMapSetting do
  it "accepts a valid registry-backed setting" do
    expect(build(:garden_map_setting)).to be_valid
  end

  it "rejects unknown modes and Bundesland codes" do
    expect(build(:garden_map_setting, mode: "satellite")).not_to be_valid
    expect(build(:garden_map_setting, bundesland: "zz")).not_to be_valid
  end

  it "accepts the custom Bundesland with http(s) WMS URLs" do
    setting = build(:garden_map_setting, bundesland:     "custom",
                                         custom_dop_url: "https://wms.example.de/dop")
    expect(setting).to be_valid
  end

  it "rejects non-http custom URLs (they are fetched by every member's browser)" do
    %w[javascript:alert(1) ftp://x data:text/html,x not-a-uri:].each do |url|
      setting = build(:garden_map_setting, custom_dop_url: url)
      expect(setting).not_to be_valid, "expected #{url.inspect} to be rejected"
      expect(setting.errors[:custom_dop_url]).to be_present
    end
  end

  it "validates viewport ranges" do
    expect(build(:garden_map_setting, zoom: 0)).not_to be_valid
    expect(build(:garden_map_setting, zoom: 23)).not_to be_valid
    expect(build(:garden_map_setting, center_lat: 91)).not_to be_valid
    expect(build(:garden_map_setting, center_lng: -181)).not_to be_valid
  end

  it "falls back to the Germany-wide default viewport" do
    setting = build(:garden_map_setting)
    expect(setting.effective_center).to eq(GardenMapSetting::DEFAULT_CENTER)
    expect(setting.effective_zoom).to eq(GardenMapSetting::DEFAULT_ZOOM)

    setting.assign_attributes(center_lat: 52.5, center_lng: 9.5, zoom: 18)
    expect(setting.effective_center).to eq([52.5, 9.5])
    expect(setting.effective_zoom).to eq(18)
  end
end
