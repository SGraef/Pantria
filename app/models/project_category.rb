# frozen_string_literal: true
# typed: false

# A user-defined project category (Garten, Renovierung, ...), shown as a
# colored chip on kanban cards. Deleting one leaves its projects
# uncategorized rather than cascading.
class ProjectCategory < ApplicationRecord
  include ColorPalette

  belongs_to :household
  has_many :projects, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 },
                   uniqueness: { scope: :household_id, case_sensitive: false }
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :name) }
end
