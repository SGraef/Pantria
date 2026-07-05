# frozen_string_literal: true

# Todos can be attached to a project; unattached todos work as before.
# Deleting a project detaches its todos (dependent: :nullify) -- the work
# item survives the plan around it.
class AddProjectToTodos < ActiveRecord::Migration[8.0]
  def change
    add_reference :todos, :project, null: true, foreign_key: true
  end
end
