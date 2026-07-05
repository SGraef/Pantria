# frozen_string_literal: true

# Typed directional link between two projects: `blocked_by` (project waits
# for related_project) or `related` (neutral). Subproject nesting is NOT a
# relation -- that's projects.parent_id, because costs roll up through it.
class CreateProjectRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :project_relations do |t|
      t.references :household, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: { to_table: :projects }
      t.references :related_project, null: false, foreign_key: { to_table: :projects }
      t.string :kind, null: false # blocked_by | related
      t.timestamps
    end

    add_index :project_relations, %i[project_id related_project_id kind],
              unique: true, name: "index_project_relations_uniqueness"
  end
end
