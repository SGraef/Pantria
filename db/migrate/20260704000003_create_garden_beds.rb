# frozen_string_literal: true

# A plot in the garden -- a raised bed, a row, a balcony box. Plantings live in
# a bed so the planner can answer "what's growing where".
class CreateGardenBeds < ActiveRecord::Migration[8.0]
  def change
    create_table :garden_beds do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :location
      t.string :sun_exposure # full_sun | part_shade | full_shade
      t.text   :notes
      t.timestamps
    end

    add_index :garden_beds, %i[household_id name]
  end
end
