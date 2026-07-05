# frozen_string_literal: true

# Comments under a project discussion. user nullable so removing an
# account keeps the thread readable (todo_comments precedent).
class CreateProjectDiscussionComments < ActiveRecord::Migration[8.0]
  def change
    create_table :project_discussion_comments do |t|
      t.references :household, null: false, foreign_key: true
      t.references :project_discussion, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
