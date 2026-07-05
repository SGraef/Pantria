# frozen_string_literal: true

# The household's plant catalog: species pulled from Perenual (cached locally so
# we never depend on the API at read time / respect its rate limit) plus a
# curated planning layer Perenual doesn't provide -- sow/harvest months and a
# crop_key used to look up companion planting. Plants can also be added by hand
# (perenual_id null).
class CreatePlants < ActiveRecord::Migration[8.0]
  def change
    create_table :plants do |t|
      t.references :household, null: false, foreign_key: true
      t.integer :perenual_id
      t.string  :common_name, null: false
      t.string  :scientific_name
      t.string  :crop_key                 # normalized key for sowing/companion lookup
      t.string  :cycle                    # annual | biennial | perennial
      t.string  :sunlight                 # full_sun | part_shade | full_shade | ...
      t.string  :watering                 # frequent | average | minimum | none
      t.integer :hardiness_min
      t.integer :hardiness_max
      t.boolean :edible, default: false, null: false
      t.string  :image_url
      t.string  :external_url             # deep link to Perenual / NaturaDB
      t.integer :sow_from_month           # 1-12, curated defaults (user-editable)
      t.integer :sow_to_month
      t.integer :harvest_from_month
      t.integer :harvest_to_month
      t.text    :notes
      t.timestamps
    end

    add_index :plants, %i[household_id common_name]
    add_index :plants, %i[household_id perenual_id]
    add_index :plants, %i[household_id crop_key]
  end
end
