# frozen_string_literal: true
# typed: true

# Plantings are shared household data; any member can manage them.
class PlantingPolicy < ApplicationPolicy
  def destroy? = household_member?
end
