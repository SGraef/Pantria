# frozen_string_literal: true
# typed: false

# A user-defined project status -- one kanban column each, in `position`
# order. `done` marks statuses that count as completed: a blocked-by
# relation only blocks while the blocker's status is not done, and it also
# tells the seeder/reporting what "finished" means.
#
# No `dependent:` on projects -- a status with projects (or the household's
# last status) must not disappear; the controller guards deletion.
class ProjectStatus < ApplicationRecord
  include ColorPalette

  belongs_to :household
  has_many :projects, dependent: nil

  validates :name, presence: true, length: { maximum: 80 },
                   uniqueness: { scope: :household_id, case_sensitive: false }
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :name) }
end
