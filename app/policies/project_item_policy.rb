# frozen_string_literal: true
# typed: true

# Materials/plans are shared planning data: members manage them freely --
# including destroy, which only drops a line item, not the project.
class ProjectItemPolicy < ApplicationPolicy
  def destroy? = household_member?
end
