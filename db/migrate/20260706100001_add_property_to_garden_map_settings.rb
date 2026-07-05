# frozen_string_literal: true

# The garden map captures exactly one geometry: the household's Grundstück
# (property boundary) -- traced over the aerial imagery or adopted from the
# official ALKIS parcel. Beds are not mapped geographically; they are laid
# out in the to-scale planner inside this outline.
class AddPropertyToGardenMapSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :garden_map_settings, :property_boundary, :json # [{lat:, lng:}, ...] closed ring implied
    add_column :garden_map_settings, :property_area_sqm, :decimal, precision: 10, scale: 2 # server-computed
  end
end
