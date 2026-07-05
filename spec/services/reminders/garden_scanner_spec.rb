# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Reminders::GardenScanner do
  let(:admin)     { create(:user) }
  let(:member)    { create(:user) }
  let(:household) { create(:household, admin: admin) }
  let(:bed)       { create(:garden_bed, household: household) }
  let(:month)     { Date.current.month }
  let(:other)     { month == 1 ? 6 : 1 } # a month that is definitely not "now"

  before do
    create(:membership, user: member, household: household, role: "member")
  end

  # Explicit months keep the test independent of the real calendar month.
  def plant_with(sow: nil, harvest: nil, name: "Testplant")
    create(:plant, household: household, common_name: name,
                   sow_from_month: sow&.first, sow_to_month: sow&.last,
                   harvest_from_month: harvest&.first, harvest_to_month: harvest&.last)
  end

  it "nudges every member to sow a planned planting whose sow window is open" do
    plant = plant_with(sow: [month, month])
    planting = create(:planting, household: household, garden_bed: bed, plant: plant, status: "planned")

    expect { described_class.run(household) }
      .to change { Notification.where(kind: "garden_reminder").count }.by(2)

    n = Notification.where(kind: "garden_reminder").first
    expect(n.notifiable).to eq(planting)
    expect(n.url).to eq("/garden_beds/#{bed.id}")
    expect(Notification.where(kind: "garden_reminder").pluck(:user_id)).to contain_exactly(admin.id, member.id)
  end

  it "nudges to harvest a growing planting whose harvest window is open" do
    plant = plant_with(harvest: [month, month])
    create(:planting, household: household, garden_bed: bed, plant: plant, status: "growing")

    expect { described_class.run(household) }
      .to change { Notification.where(kind: "garden_reminder").count }.by(2)
  end

  it "does not nudge to sow once a planting is already sown/growing" do
    plant = plant_with(sow: [month, month])
    create(:planting, household: household, garden_bed: bed, plant: plant, status: "growing")
    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "ignores harvested plantings and windows that aren't open now" do
    create(:planting, household: household, garden_bed: bed, status: "harvested",
                      plant: plant_with(sow: [month, month]))
    create(:planting, household: household, garden_bed: bed, status: "planned",
                      plant: plant_with(sow: [other, other], name: "Elsewhere"))
    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "is idempotent within the same month" do
    plant = plant_with(sow: [month, month])
    create(:planting, household: household, garden_bed: bed, plant: plant, status: "planned")

    described_class.run(household)
    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "skips members who opted out of the garden_reminder kind" do
    member.notification_preference.update!(disabled_kinds: ["garden_reminder"])
    plant = plant_with(sow: [month, month])
    create(:planting, household: household, garden_bed: bed, plant: plant, status: "planned")

    expect { described_class.run(household) }
      .to change { Notification.where(kind: "garden_reminder").count }.by(1)
    expect(Notification.where(kind: "garden_reminder").pluck(:user_id)).to contain_exactly(admin.id)
  end
end
