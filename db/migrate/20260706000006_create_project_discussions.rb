# frozen_string_literal: true

# Resolvable discussion threads on a project (decisions, open questions).
# The kanban card counts threads still in status "open".
class CreateProjectDiscussions < ActiveRecord::Migration[8.0]
  def change
    create_table :project_discussions do |t|
      t.references :household, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "open" # open | resolved
      t.references :creator, null: true, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :project_discussions, %i[project_id status]
  end
end
