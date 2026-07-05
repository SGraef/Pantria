# frozen_string_literal: true
# typed: false

# A comment under a project discussion. The author is optional so removing
# an account keeps the thread readable (todo_comments precedent).
class ProjectDiscussionComment < ApplicationRecord
  belongs_to :household
  belongs_to :project_discussion
  belongs_to :user, optional: true

  before_validation :inherit_household

  validates :body, presence: true, length: { maximum: 4000 }

  private

  def inherit_household
    self.household ||= project_discussion&.household
  end
end
