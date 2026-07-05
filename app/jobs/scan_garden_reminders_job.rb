# frozen_string_literal: true
# typed: false

# Daily scan that nudges household members to sow or harvest plantings whose
# curated window is open this month. Scoped to the sole household
# ({Household.current}); a no-op when there is none. Wired in
# config/recurring.yml.
class ScanGardenRemindersJob < ApplicationJob
  queue_as :default

  def perform
    created = Reminders::GardenScanner.run
    Rails.logger.info("[reminders] garden scan created #{created} notification(s)") if created.positive?
    created
  end
end
