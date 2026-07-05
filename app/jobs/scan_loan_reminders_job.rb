# frozen_string_literal: true
# typed: false

# Daily scan that reminds members about outstanding loans when an upcoming
# calendar event mentions the other person. Scoped to the sole household; a
# no-op when there is none. Wired in config/recurring.yml.
class ScanLoanRemindersJob < ApplicationJob
  queue_as :default

  def perform
    created = Reminders::LoanCalendarScanner.run
    Rails.logger.info("[reminders] loan scan created #{created} notification(s)") if created.positive?
    created
  end
end
