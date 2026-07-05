# frozen_string_literal: true

# Per-household configuration for the garden map: which mode it runs in
# (Leaflet map over official WMS layers vs. the abstract lite planner), which
# Bundesland's geodata services to use, the saved viewport, and custom WMS
# fields for states we haven't verified endpoints for yet.
class CreateGardenMapSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :garden_map_settings do |t|
      t.references :household, null: false, foreign_key: true, index: { unique: true }
      t.string  :mode, null: false, default: "map" # map | lite
      t.string  :bundesland, default: "ni"         # Garden::MapSources key or "custom"
      t.decimal :center_lat, precision: 10, scale: 7 # saved viewport
      t.decimal :center_lng, precision: 10, scale: 7
      t.integer :zoom
      t.string  :custom_dop_url, limit: 500 # escape hatch: own WMS endpoints
      t.string  :custom_dop_layer
      t.string  :custom_alkis_url, limit: 500
      t.string  :custom_alkis_layer
      t.timestamps
    end
  end
end
