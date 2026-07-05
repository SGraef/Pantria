# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Garden::Geocoder do
  let(:endpoint) { %r{nominatim\.openstreetmap\.org/search} }

  it "returns the first match with coordinates" do
    stub_request(:get, endpoint).to_return(
      status: 200,
      body:   [{ lat: "52.3705", lon: "9.7332", display_name: "Hannover, Niedersachsen" }].to_json
    )
    result = described_class.search("Hannah-Arendt-Platz 1, Hannover")
    expect(result.lat).to eq(52.3705)
    expect(result.lng).to eq(9.7332)
    expect(result.display_name).to include("Hannover")
  end

  it "sends an identifying User-Agent (Nominatim usage policy)" do
    stub = stub_request(:get, endpoint)
           .with(headers: { "User-Agent" => /Pantria/ })
           .to_return(status: 200, body: "[]")
    described_class.search("Hannover")
    expect(stub).to have_been_requested
  end

  it "returns nil for blank queries without any request" do
    stub = stub_request(:get, endpoint)
    expect(described_class.search("  ")).to be_nil
    expect(stub).not_to have_been_requested
  end

  it "returns nil on empty results, HTTP errors, and timeouts" do
    stub_request(:get, endpoint).to_return(status: 200, body: "[]")
    expect(described_class.search("Nowhere")).to be_nil

    stub_request(:get, endpoint).to_return(status: 503)
    expect(described_class.search("Hannover")).to be_nil

    stub_request(:get, endpoint).to_timeout
    expect(described_class.search("Hannover")).to be_nil
  end
end
