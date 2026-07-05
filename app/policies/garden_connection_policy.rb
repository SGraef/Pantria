# frozen_string_literal: true
# typed: true

# The garden connection holds a Perenual API key and drives outbound API
# traffic -- admin-only, like the paperless and calendar connections.
class GardenConnectionPolicy < ApplicationPolicy
  def show?    = household_admin?
  def new?     = household_admin?
  def create?  = household_admin?
  def update?  = household_admin?
  def destroy? = household_admin?
end
