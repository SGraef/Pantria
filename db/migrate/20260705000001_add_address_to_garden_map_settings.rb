# frozen_string_literal: true

# Free-text address for the "find my garden" lookup. Geocoded server-side
# (Nominatim) into the saved viewport; kept so the settings form can show
# what was searched.
class AddAddressToGardenMapSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :garden_map_settings, :address, :string, limit: 200
  end
end
