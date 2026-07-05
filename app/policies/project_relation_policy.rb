# frozen_string_literal: true
# typed: true

# Relations are lightweight planning links -- members add and remove them.
class ProjectRelationPolicy < ApplicationPolicy
  def destroy? = household_member?
end
