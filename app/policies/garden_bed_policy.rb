# frozen_string_literal: true
# typed: true

# Garden beds are shared household data; any member can manage them (same
# posture as the grocery list / todos / plant catalog).
class GardenBedPolicy < ApplicationPolicy
  def destroy? = household_member?
end
