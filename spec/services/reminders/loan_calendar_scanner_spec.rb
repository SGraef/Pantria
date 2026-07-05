# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe Reminders::LoanCalendarScanner do
  let(:admin) { create(:user) }
  # Window is today .. today + LOAN_REMINDER_DAYS (default 2); pin "soon" inside it.
  let(:soon) { 1.day.from_now.change(hour: 12) }
  let(:member)    { create(:user) }
  let(:household) { create(:household, admin: admin) }

  before do
    create(:membership, user: member, household: household, role: "member")
  end

  def event(title, at: soon)
    create(:calendar_event, household: household, title: title, starts_at: at)
  end

  it "reminds every member when an upcoming event mentions an outstanding loan's counterparty" do
    loan = create(:loan, household: household, item: "Drill", counterparty: "Anna Müller")
    ev   = event("Coffee with Anna Müller")

    expect { described_class.run(household) }
      .to change { Notification.where(kind: "loan_reminder").count }.by(2)

    notification = Notification.where(kind: "loan_reminder").first
    expect(notification.notifiable).to eq(loan)
    expect(notification.url).to eq("/loans")
    expect(Notification.where(kind: "loan_reminder").pluck(:user_id)).to contain_exactly(admin.id, member.id)
    expect(ev.title).to include("Anna")
  end

  it "matches case- and accent-insensitively (event title vs counterparty_key)" do
    create(:loan, household: household, counterparty: "Müller")
    event("Lunch with MÜLLER")
    expect { described_class.run(household) }.to change(Notification, :count).by(2)
  end

  it "ignores returned loans and non-matching events" do
    create(:loan, :returned, household: household, counterparty: "Anna")
    create(:loan, household: household, counterparty: "Bob")
    event("Meeting with Anna")      # only matches the returned loan
    event("Standup", at: soon)      # matches nobody

    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "ignores events outside the look-ahead window" do
    create(:loan, household: household, counterparty: "Anna")
    event("Anna", at: 10.days.from_now.change(hour: 12))

    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "is idempotent per loan/event/recipient" do
    create(:loan, household: household, counterparty: "Anna")
    event("Anna")

    described_class.run(household)
    expect { described_class.run(household) }.not_to change(Notification, :count)
  end

  it "skips members who opted out of the loan_reminder kind" do
    member.notification_preference.update!(disabled_kinds: ["loan_reminder"])
    create(:loan, household: household, counterparty: "Anna")
    event("Anna")

    expect { described_class.run(household) }
      .to change { Notification.where(kind: "loan_reminder").count }.by(1)
    expect(Notification.where(kind: "loan_reminder").pluck(:user_id)).to contain_exactly(admin.id)
  end
end
