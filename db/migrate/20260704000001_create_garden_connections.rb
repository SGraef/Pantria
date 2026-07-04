# frozen_string_literal: true

# A household's optional binding to the Perenual plant API (perenual.com): an
# encrypted API key plus the local growing context (hardiness zone / region)
# used to tailor the sowing calendar. Singular -- one per household, like the
# paperless and calendar connections.
class CreateGardenConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :garden_connections do |t|
      t.references :household, null: false, foreign_key: true, index: { unique: true }
      t.text   :api_key            # encrypted at rest (Active Record encryption)
      t.string :hardiness_zone     # e.g. "7" -- Central Europe default
      t.string :region             # free-text label, optional
      t.string :last_error, limit: 1000
      t.datetime :last_synced_at
      t.timestamps
    end
  end
end
