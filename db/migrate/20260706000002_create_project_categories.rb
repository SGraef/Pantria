# frozen_string_literal: true

# User-definable project categories (Garten, Renovierung, ...) shown as a
# colored chip on kanban cards. Same shape as offer categories.
class CreateProjectCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :project_categories do |t|
      t.references :household, null: false, foreign_key: true
      t.string  :name, null: false
      t.integer :position, null: false, default: 0
      t.string  :color # ColorPalette key, blank = neutral
      t.timestamps
    end

    add_index :project_categories, %i[household_id position]
    add_index :project_categories, %i[household_id name], unique: true
  end
end
