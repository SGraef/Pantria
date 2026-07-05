# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Project do
  let(:household) { create(:household) }

  describe "budget accessor pair" do
    it "converts between euros and cents" do
      project = build(:project, household:, budget: "1234.56")
      expect(project.budget_cents).to eq(123_456)
      expect(project.budget).to eq(BigDecimal("1234.56"))

      project.budget = ""
      expect(project.budget_cents).to be_nil
      expect(project.budget).to be_nil
    end

    it "rejects negative budgets" do
      expect(build(:project, household:, budget_cents: -1)).not_to be_valid
    end
  end

  describe "household consistency" do
    it "rejects a status or category from another household" do
      other = create(:household)
      expect(build(:project, household:, project_status: other.project_statuses.first)).not_to be_valid
      foreign_category = create(:project_category, household: other)
      expect(build(:project, household:, project_category: foreign_category)).not_to be_valid
    end
  end

  describe "parent nesting" do
    it "rejects self and cycles" do
      project = create(:project, household:)
      project.parent = project
      expect(project).not_to be_valid
      project.reload

      child = create(:project, household:, parent: project)
      project.parent = child
      expect(project).not_to be_valid
    end

    it "promotes children when the parent is destroyed" do
      parent = create(:project, household:)
      child = create(:project, household:, parent: parent)
      parent.destroy
      expect(child.reload.parent_id).to be_nil
    end
  end

  describe "#blocked?" do
    let(:project) { create(:project, household:) }
    let(:blocker) { create(:project, household:) }

    before do
      create(:project_relation, project: project, related_project: blocker, kind: "blocked_by")
    end

    it "is blocked while the blocker's status is not done" do
      expect(project).to be_blocked
    end

    it "unblocks when the blocker reaches a done status" do
      blocker.update!(project_status: household.project_statuses.find_by(done: true))
      expect(project).not_to be_blocked
    end

    it "ignores neutral related links" do
      other = create(:project, household:)
      create(:project_relation, project: project, related_project: other, kind: "related")
      blocker.update!(project_status: household.project_statuses.find_by(done: true))
      expect(project).not_to be_blocked
    end
  end

  it "destroys relations in both directions with the project" do
    a = create(:project, household:)
    b = create(:project, household:)
    create(:project_relation, project: a, related_project: b, kind: "related")
    expect { b.destroy }.to change(ProjectRelation, :count).by(-1)
  end
end
