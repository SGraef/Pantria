# frozen_string_literal: true

# A household project (renovation, build, ...). Lives in exactly one
# user-defined status (= kanban column, ordered by position within it),
# optionally categorized and nested under a parent project (subprojects
# roll their costs up). budget_cents nullable = no budget set; the actual
# cost is always derived from the project's items (+ children).
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.text   :description
      t.references :project_status, null: false, foreign_key: true
      t.references :project_category, null: true, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :projects }
      t.integer :budget_cents
      t.string  :currency, null: false, default: "EUR", limit: 3
      t.integer :position, null: false, default: 0 # board order within the status column
      t.references :creator, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :projects, %i[household_id project_status_id position], name: "index_projects_on_board_order"
  end
end
