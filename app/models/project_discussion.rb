# frozen_string_literal: true
# typed: false

# A resolvable discussion thread on a project (a decision to make, an open
# question). The kanban card counts threads still open; resolving keeps the
# thread and its comments readable.
class ProjectDiscussion < ApplicationRecord
  STATUSES = %w[open resolved].freeze

  belongs_to :household
  belongs_to :project
  belongs_to :creator, class_name: "User", optional: true

  has_many :project_discussion_comments, -> { order(:created_at) },
           dependent: :destroy, inverse_of: :project_discussion

  before_validation :inherit_household

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }

  scope :open_state, -> { where(status: "open") }

  def resolved? = status == "resolved"

  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
  end

  def reopen!
    update!(status: "open", resolved_at: nil)
  end

  private

  def inherit_household
    self.household ||= project&.household
  end
end
