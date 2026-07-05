# frozen_string_literal: true
# typed: true

# Any member opens, resolves and reopens threads; removing a whole thread
# (with its comments) stays admin-only via the ApplicationPolicy default.
class ProjectDiscussionPolicy < ApplicationPolicy
  def resolve? = household_member?
  def reopen?  = household_member?
end
