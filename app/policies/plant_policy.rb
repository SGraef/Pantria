# frozen_string_literal: true
# typed: true

# The plant catalog is shared household data; any member can browse, import and
# manage it (same posture as the grocery list / todos / loans).
class PlantPolicy < ApplicationPolicy
  def search?  = household_member?
  def import?  = household_member?
  def destroy? = household_member?
end
