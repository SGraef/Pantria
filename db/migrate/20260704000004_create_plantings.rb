# frozen_string_literal: true

# A plant placed in a bed: the concrete "I sowed 4 tomatoes in Bed 1" record.
# Its status (planned -> sown -> growing -> harvested) and the plant's sow/harvest
# windows drive the garden reminders.
class CreatePlantings < ActiveRecord::Migration[8.0]
  def change
    create_table :plantings do |t|
      t.references :household,  null: false, foreign_key: true
      t.references :garden_bed, null: false, foreign_key: true
      t.references :plant,      null: false, foreign_key: true
      t.integer :quantity, default: 1, null: false
      t.string  :status, default: "planned", null: false # planned|sown|growing|harvested
      t.date    :sown_on
      t.date    :planted_out_on
      t.date    :expected_harvest_on
      t.date    :harvested_on
      t.text    :notes
      t.timestamps
    end

    add_index :plantings, %i[household_id status]
  end
end
