# frozen_string_literal: true

# Materials and plans of a project -- one table, distinguished by kind,
# because their shape is identical: a name plus any of link, file
# (Active Storage) and cost. cost_cents nullable = no cost known (yet);
# the project's actual cost is the sum over its items.
class CreateProjectItems < ActiveRecord::Migration[8.0]
  def change
    create_table :project_items do |t|
      t.references :household, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string  :kind, null: false # material | plan
      t.string  :name, null: false
      t.string  :url
      t.integer :cost_cents
      t.text    :notes
      t.timestamps
    end

    add_index :project_items, %i[project_id kind]
  end
end
