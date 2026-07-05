# frozen_string_literal: true

# User-definable project statuses -- one kanban column each, ordered by
# position (gap-of-10 like offer categories). `done` marks statuses that
# count as completed: blocked-by relations only block while the blocker's
# status is not done.
class CreateProjectStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :project_statuses do |t|
      t.references :household, null: false, foreign_key: true
      t.string  :name, null: false
      t.integer :position, null: false, default: 0
      t.string  :color # ColorPalette key, blank = neutral
      t.boolean :done, null: false, default: false
      t.timestamps
    end

    add_index :project_statuses, %i[household_id position]
    add_index :project_statuses, %i[household_id name], unique: true
  end
end
