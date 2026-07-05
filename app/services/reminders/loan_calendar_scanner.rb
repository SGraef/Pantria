# frozen_string_literal: true
# typed: false

module Reminders
  # "You're about to see this person — settle the loan" signal. For each
  # upcoming calendar event, if its title mentions the counterparty of an
  # outstanding {Loan}, notify household members so they remember to bring the
  # borrowed item back (or collect the lent one).
  #
  # People match by name substring against the event title (transliterated +
  # downcased), the same loose rule the offer watchlist uses -- calendar events
  # carry only a title, no structured attendees.
  #
  # Idempotent: dedup_key pins each notification to (loan, event, recipient), so
  # the daily scan never double-alerts for the same meeting, while a new event
  # with that person (a fresh id) alerts again.
  class LoanCalendarScanner
    KIND = "loan_reminder"
    # How many days ahead to look for meetings (today .. today + WINDOW_DAYS).
    WINDOW_DAYS = ENV.fetch("LOAN_REMINDER_DAYS", "2").to_i

    # @param household [Household, nil] defaults to the sole household.
    # @return [Integer] number of notifications newly created this run.
    def self.run(household = Household.current)
      new(household).run
    end

    def initialize(household)
      @household = household
    end

    def run
      return 0 if @household.nil?

      loans = @household.loans.outstanding.to_a
      return 0 if loans.empty?

      @recipients = @household.users.to_a
      return 0 if @recipients.empty?

      upcoming_events.sum do |event|
        title = Loan.normalize(event.title)
        loans.select { |loan| loan.counterparty_key.present? && title.include?(loan.counterparty_key) }
             .sum { |loan| notify(loan, event) }
      end
    end

    private

    def upcoming_events
      from = Time.current.beginning_of_day
      to   = (Date.current + WINDOW_DAYS).end_of_day
      @household.calendar_events.starting_between(from, to).order(:starts_at)
    end

    def notify(loan, event)
      @recipients.count do |user|
        next false unless user.notification_preference.allows?(KIND)

        Notification.deliver(
          dedup_key:  "#{KIND}:#{loan.id}:#{event.id}:#{user.id}",
          household:  @household,
          user:       user,
          notifiable: loan,
          kind:       KIND,
          title:      I18n.t("notification.loan_reminder.title", person: loan.counterparty),
          body:       I18n.t("notification.loan_reminder.#{loan.direction}",
                             item: loan.item, person: loan.counterparty, event: event.title),
          url:        "/loans"
        ).previously_new_record?
      end
    end
  end
end
