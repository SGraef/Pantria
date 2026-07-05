# frozen_string_literal: true

# Geometry for the garden map. A bed carries either a traced polygon from the
# map view (boundary, WGS84 ring) or manual dimensions for the lite planner
# (width/length plus a position on the abstract canvas) -- or both, when the
# household switched modes. area_sqm is denormalized so lists can show sizes
# without geometry math; the model recomputes it on every save.
class AddMapGeometryToGardenBeds < ActiveRecord::Migration[8.0]
  def change
    add_column :garden_beds, :boundary, :json # map mode: [{lat:, lng:}, ...] closed ring implied
    add_column :garden_beds, :width_m,  :decimal, precision: 6, scale: 2 # lite mode dimensions (meters)
    add_column :garden_beds, :length_m, :decimal, precision: 6, scale: 2
    add_column :garden_beds, :pos_x_m,  :decimal, precision: 7, scale: 2 # lite canvas origin (meters)
    add_column :garden_beds, :pos_y_m,  :decimal, precision: 7, scale: 2
    add_column :garden_beds, :area_sqm, :decimal, precision: 8, scale: 2 # server-computed, boundary wins
  end
end
