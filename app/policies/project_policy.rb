# frozen_string_literal: true
# typed: true

# Projects are shared household data: members do everything, destroy stays
# admin-only via the ApplicationPolicy default. `move?` covers the kanban
# drag (and its no-JS fallback), mirroring TodoPolicy#transition?.
class ProjectPolicy < ApplicationPolicy
  def move? = household_member?
end
