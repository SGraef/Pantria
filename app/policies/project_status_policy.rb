# frozen_string_literal: true
# typed: true

# Statuses define the kanban columns -- shared structure any member may
# curate (offer categories precedent); destroy stays admin-only via the
# ApplicationPolicy default.
class ProjectStatusPolicy < ApplicationPolicy
end
