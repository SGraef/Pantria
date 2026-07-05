# frozen_string_literal: true
# typed: false

# Typed directional link between two projects of the same household:
# `blocked_by` (project waits for related_project to reach a done status)
# or `related` (neutral). The inverse-duplicate check rejects mirrored rows
# of the same kind -- mutual "related" would be redundant, and mutual
# "blocked_by" would deadlock both projects.
class ProjectRelation < ApplicationRecord
  KINDS = %w[blocked_by related].freeze

  belongs_to :household
  belongs_to :project
  belongs_to :related_project, class_name: "Project"

  before_validation :inherit_household

  validates :kind, inclusion: { in: KINDS }
  validates :related_project_id, uniqueness: { scope: %i[project_id kind] }
  validate :not_self_referential
  validate :no_inverse_duplicate
  validate :same_household

  private

  def inherit_household
    self.household ||= project&.household
  end

  def not_self_referential
    errors.add(:related_project, :invalid) if project_id.present? && project_id == related_project_id
  end

  def no_inverse_duplicate
    return if project_id.nil? || related_project_id.nil?

    inverse = ProjectRelation.where(project_id: related_project_id,
                                    related_project_id: project_id, kind: kind)
    inverse = inverse.where.not(id: id) if persisted?
    errors.add(:related_project, :taken) if inverse.exists?
  end

  def same_household
    return if related_project.nil? || household_id.nil?
    return if related_project.household_id == household_id

    errors.add(:related_project, :invalid)
  end
end
