# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe ProjectItem do
  let(:household) { create(:household) }
  let(:project) { create(:project, household:) }

  it "inherits the household from its project" do
    expect(create(:project_item, project:).household).to eq(household)
  end

  it "validates kind, url scheme and cost" do
    expect(build(:project_item, project:, kind: "tool")).not_to be_valid
    expect(build(:project_item, project:, url: "javascript:alert(1)")).not_to be_valid
    expect(build(:project_item, project:, url: "https://shop.example.de/x")).to be_valid
    expect(build(:project_item, project:, cost_cents: -1)).not_to be_valid
  end

  it "converts cost euros to cents and back" do
    item = build(:project_item, project:, cost: "19.99")
    expect(item.cost_cents).to eq(1999)
    expect(item.cost).to eq(BigDecimal("19.99"))
  end

  it "accepts allowed file types and rejects others" do
    expect(build(:project_item, :with_file, project:)).to be_valid

    item = build(:project_item, project:)
    item.file.attach(io: StringIO.new("MZ fake"), filename: "x.exe",
                     content_type: "application/x-msdownload")
    expect(item).not_to be_valid
  end

  describe "cost roll-up on Project" do
    it "sums items and rolls subproject costs into the parent" do
      parent = create(:project, household:, budget: "100.00")
      child = create(:project, household:, parent: parent)
      create(:project_item, project: parent, cost: "40.00")
      create(:project_item, :plan, project: child, cost: "70.00")
      create(:project_item, project: child) # no cost -> counts as 0

      expect(parent.own_cost_cents).to eq(4000)
      expect(parent.actual_cost_cents).to eq(11_000)
      expect(parent).to be_over_budget

      totals = Project.actual_costs_by_id([parent, child])
      expect(totals[parent.id]).to eq(11_000)
      expect(totals[child.id]).to eq(7000)
    end
  end
end
