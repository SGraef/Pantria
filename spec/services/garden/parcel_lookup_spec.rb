# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Garden::ParcelLookup do
  let(:source) { Garden::MapSources.fetch("ni")[:parcels] }
  let(:endpoint) { %r{opendata\.lgln\.niedersachsen\.de/doorman/noauth/alkis_wfs_einfach} }
  let(:gml) { Rails.root.join("spec/fixtures/garden/alkis_flurstueck.xml").read }

  it "returns the parcel outline with its official area and label" do
    stub_request(:get, endpoint).to_return(status: 200, body: gml)
    parcel = described_class.at(lat: 52.3705, lng: 9.7332, source: source)

    expect(parcel.boundary.length).to eq(4)
    expect(parcel.boundary.first).to eq({ lat: 52.3708978, lng: 9.7316866 })
    expect(parcel.area_sqm).to eq(13_452.0)
    expect(parcel.label).to eq("Hannah-Arendt-Platz 1")
    expect(parcel.parcel_key).to eq("034880048000430008__")
  end

  it "queries a tiny BBOX around the point in EPSG:4326" do
    stub = stub_request(:get, endpoint)
           .with(query: hash_including("REQUEST" => "GetFeature", "TYPENAMES" => "ave:Flurstueck"))
           .to_return(status: 200, body: gml)
    described_class.at(lat: 52.3705, lng: 9.7332, source: source)
    expect(stub).to have_been_requested
  end

  it "returns nil without a source, on empty collections, and on failures" do
    expect(described_class.at(lat: 52.0, lng: 9.0, source: nil)).to be_nil

    empty = '<?xml version="1.0"?>' \
            '<wfs:FeatureCollection xmlns:wfs="http://www.opengis.net/wfs/2.0" numberReturned="0"/>'
    stub_request(:get, endpoint).to_return(status: 200, body: empty)
    expect(described_class.at(lat: 52.0, lng: 9.0, source: source)).to be_nil

    stub_request(:get, endpoint).to_return(status: 502)
    expect(described_class.at(lat: 52.0, lng: 9.0, source: source)).to be_nil

    stub_request(:get, endpoint).to_timeout
    expect(described_class.at(lat: 52.0, lng: 9.0, source: source)).to be_nil
  end
end
