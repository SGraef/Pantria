# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe ProjectStatus do
  let(:household) { create(:household) }

  it "seeds four German defaults on household creation, idempotently" do
    expect(household.project_statuses.ordered.pluck(:name))
      .to eq(["Idee", "Geplant", "In Arbeit", "Erledigt"])
    expect(household.project_statuses.find_by(name: "Erledigt")).to be_done

    expect { ProjectStatusSeeder.call(household) }.not_to change(described_class, :count)
  end

  it "enforces case-insensitive unique names per household" do
    expect(build(:project_status, household:, name: "idee")).not_to be_valid
    expect(build(:project_status, household: create(:household), name: "Extra")).to be_valid
  end

  it "accepts only palette colors" do
    expect(build(:project_status, household:, color: "sky")).to be_valid
    expect(build(:project_status, household:, color: "")).to be_valid
    expect(build(:project_status, household:, color: "#ff0000")).not_to be_valid
  end
end
