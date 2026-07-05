# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe ProjectRelation do
  let(:household) { create(:household) }
  let(:a) { create(:project, household:) }
  let(:b) { create(:project, household:) }

  it "inherits the household from its project" do
    relation = create(:project_relation, project: a, related_project: b)
    expect(relation.household).to eq(household)
  end

  it "rejects unknown kinds, self-links and duplicates" do
    expect(build(:project_relation, project: a, related_project: b, kind: "friends")).not_to be_valid
    expect(build(:project_relation, project: a, related_project: a)).not_to be_valid

    create(:project_relation, project: a, related_project: b, kind: "related")
    expect(build(:project_relation, project: a, related_project: b, kind: "related")).not_to be_valid
  end

  it "rejects the mirrored duplicate of the same kind" do
    create(:project_relation, project: a, related_project: b, kind: "blocked_by")
    expect(build(:project_relation, project: b, related_project: a, kind: "blocked_by")).not_to be_valid
    # A different kind in the other direction is fine.
    expect(build(:project_relation, project: b, related_project: a, kind: "related")).to be_valid
  end

  it "rejects cross-household links" do
    foreign = create(:project, household: create(:household))
    expect(build(:project_relation, project: a, related_project: foreign)).not_to be_valid
  end
end
