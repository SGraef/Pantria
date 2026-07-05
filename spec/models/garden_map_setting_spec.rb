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

  describe "property boundary" do
    # Roughly 10 m x 10 m square near Hannover => ~100 m2.
    let(:ring) do
      step = 10.0 / Garden::Geometry::EARTH_RADIUS_M * 180 / Math::PI
      lng_step = step / Math.cos(52 * Math::PI / 180)
      [{ "lat" => 52.0, "lng" => 9.0 },
       { "lat" => 52.0, "lng" => 9.0 + lng_step },
       { "lat" => 52.0 + step, "lng" => 9.0 + lng_step },
       { "lat" => 52.0 + step, "lng" => 9.0 }]
    end

    it "accepts a valid ring and computes the property area on save" do
      setting = create(:garden_map_setting, property_boundary: ring)
      expect(setting.property_area_sqm).to be_within(1).of(100)
      expect(setting).to be_property
    end

    it "clears the area with the boundary" do
      setting = create(:garden_map_setting, property_boundary: ring)
      setting.update!(property_boundary: nil)
      expect(setting.property_area_sqm).to be_nil
    end

    it "rejects malformed rings" do
      expect(build(:garden_map_setting, property_boundary: "shape")).not_to be_valid
      expect(build(:garden_map_setting, property_boundary: ring.first(2))).not_to be_valid
      bad = ring.first(2) + [{ "lat" => 999, "lng" => 9.0 }]
      expect(build(:garden_map_setting, property_boundary: bad)).not_to be_valid
    end
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
