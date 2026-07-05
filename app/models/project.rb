# frozen_string_literal: true
# typed: false

# A household project (renovation, build-out, garden structure, ...).
#
# Structure: exactly one user-defined {ProjectStatus} (= kanban column;
# `position` orders the card within it), optional {ProjectCategory},
# optional parent for subproject nesting. Typed peer links (blocked_by /
# related) live in {ProjectRelation}; nesting is parent_id because costs
# roll up through it.
#
# Costs: `budget_cents` is the optional plan; the actual is always derived
# from the project's items plus its children's actuals. "Blocked" means a
# DIRECT blocker whose status is not `done` -- deliberately non-transitive,
# which also keeps relation cycles harmless.
class Project < ApplicationRecord
  belongs_to :household
  belongs_to :project_status
  belongs_to :project_category, optional: true
  belongs_to :parent, class_name: "Project", optional: true
  belongs_to :creator, class_name: "User", optional: true

  # Deleting a parent promotes its children to top level -- their data
  # (items, discussions, todos) must survive the parent's removal.
  has_many :children, class_name: "Project", foreign_key: :parent_id,
                      dependent: :nullify, inverse_of: :parent
  has_many :project_items, dependent: :destroy
  # Scoped views of :project_items (which owns the dependent cleanup).
  has_many :materials, -> { where(kind: "material") },
           class_name: "ProjectItem", inverse_of: :project, dependent: nil
  has_many :plans, -> { where(kind: "plan") },
           class_name: "ProjectItem", inverse_of: :project, dependent: nil
  has_many :project_discussions, dependent: :destroy
  has_many :todos, dependent: :nullify
  has_many :relations, class_name: "ProjectRelation", dependent: :destroy,
                       inverse_of: :project
  has_many :inverse_relations, class_name: "ProjectRelation",
                               foreign_key: :related_project_id,
                               dependent: :destroy, inverse_of: :related_project
  # Scoped view of :relations (which owns the dependent cleanup).
  has_many :blocked_by_relations, -> { where(kind: "blocked_by") },
           class_name: "ProjectRelation", inverse_of: :project, dependent: nil
  has_many :blockers, through: :blocked_by_relations, source: :related_project

  MAX_PARENT_DEPTH = 50

  validates :name, presence: true, length: { maximum: 200 }
  validates :budget_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                           allow_nil:    true
  validates :currency, length: { is: 3 }
  validates :position, numericality: { only_integer: true }
  validate :status_in_household
  validate :category_in_household
  validate :parent_in_household
  validate :parent_not_circular

  scope :ordered, -> { order(:position, :name) }

  # BigDecimal accessor pair over the cents column (Price#amount pattern).
  def budget
    budget_cents && (BigDecimal(budget_cents.to_s) / 100)
  end

  def budget=(value)
    self.budget_cents = value.blank? ? nil : (BigDecimal(value.to_s) * 100).to_i
  end

  # @return [Integer] cents from this project's own items only
  def own_cost_cents
    project_items.sum(Arel.sql("COALESCE(cost_cents, 0)"))
  end

  # @return [Integer] own items plus all descendants' actuals. Fine on a
  #   show page; use {.actual_costs_by_id} when rendering many projects.
  def actual_cost_cents
    own_cost_cents + children.sum(&:actual_cost_cents)
  end

  # Batch actuals for the board: one grouped SUM over all items, then fold
  # children into parents bottom-up. `projects` must be the household's
  # complete set or subtree roll-ups would silently miss members.
  # @param projects [Array<Project>]
  # @return [Hash{Integer=>Integer}] project id => actual cents
  def self.actual_costs_by_id(projects)
    own = ProjectItem.where(project_id: projects.map(&:id))
                     .group(:project_id)
                     .sum(Arel.sql("COALESCE(cost_cents, 0)"))
    totals = projects.to_h { |p| [p.id, own.fetch(p.id, 0)] }
    by_parent = projects.group_by(&:parent_id)

    fold = lambda do |project|
      children = by_parent.fetch(project.id, [])
      totals[project.id] += children.sum { |c| fold.call(c) }
      totals[project.id]
    end
    by_parent.fetch(nil, []).each { |root| fold.call(root) }
    totals
  end

  # @param actual [Integer] pass a precomputed value on the board to avoid N+1
  def over_budget?(actual = actual_cost_cents)
    budget_cents.present? && actual > budget_cents
  end

  # A direct blocker in a not-done status blocks this project.
  def blocked?
    blockers.joins(:project_status).exists?(project_statuses: { done: false })
  end

  private

  def status_in_household
    return if project_status.nil? || project_status.household_id == household_id

    errors.add(:project_status, :invalid)
  end

  def category_in_household
    return if project_category.nil? || project_category.household_id == household_id

    errors.add(:project_category, :invalid)
  end

  def parent_in_household
    return if parent.nil? || parent.household_id == household_id

    errors.add(:parent, :invalid)
  end

  # actual_cost_cents recurses over children, so the parent chain must stay
  # acyclic. Walk upwards (bounded) and reject reaching self.
  def parent_not_circular
    return if parent_id.nil?
    return errors.add(:parent, :invalid) if parent_id == id

    node = parent
    MAX_PARENT_DEPTH.times do
      return if node.nil?
      return errors.add(:parent, :invalid) if node.id == id

      node = node.parent
    end
    errors.add(:parent, :invalid) # deeper than any sane household nesting
  end
end
