# frozen_string_literal: true
# typed: true

# Map settings choose which external WMS endpoints every member's browser
# loads tiles from, so editing is admin-only (same posture as the other
# connections). Viewing the map itself is shared garden data -- any member.
class GardenMapSettingPolicy < ApplicationPolicy
  def show?    = household_member?
  def create?  = household_admin?
  def update?  = household_admin?
end
