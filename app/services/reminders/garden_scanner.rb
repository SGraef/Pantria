# frozen_string_literal: true
# typed: false

module Reminders
  # "Time to sow / time to harvest" signal of the proactive-reminders engine
  # (signal #4). Walks the household's plantings and, using each plant's curated
  # sow/harvest window ({Garden::Catalog}) against the current month, nudges
  # members to act:
  #
  #   * sow     — a still-`planned` planting whose sow window includes this month.
  #   * harvest — a `sown`/`growing` planting whose harvest window is open.
  #
  # Reuses the {Notification} ledger (bell + push) and each member's
  # notification preferences. Idempotent: the dedup_key pins each notification to
  # (signal, planting, year-month, recipient), so the daily scan alerts once per
  # calendar month per planting -- a fresh month re-nudges.
  class GardenScanner
    KIND = "garden_reminder"

    # @param household [Household, nil] defaults to the sole household.
    # @return [Integer] number of notifications newly created this run.
    def self.run(household = Household.current)
      new(household).run
    end

    def initialize(household)
      @household = household
      @month = Date.current.month
      @stamp = Date.current.strftime("%Y-%m")
    end

    def run
      return 0 if @household.nil?

      @recipients = @household.users.to_a
      return 0 if @recipients.empty?

      @household.plantings.active.includes(:plant, :garden_bed).sum do |planting|
        if planting.awaiting_sowing? && planting.sow_month?(@month)
          notify(planting, signal: "sow")
        elsif planting.growing? && planting.harvest_month?(@month)
          notify(planting, signal: "harvest")
        else
          0
        end
      end
    end

    private

    def notify(planting, signal:)
      plant = planting.common_name
      bed   = planting.garden_bed.name

      @recipients.count do |user|
        next false unless user.notification_preference.allows?(KIND)

        Notification.deliver(
          dedup_key:  "#{KIND}:#{signal}:#{planting.id}:#{@stamp}:#{user.id}",
          household:  @household,
          user:       user,
          notifiable: planting,
          kind:       KIND,
          title:      I18n.t("notification.garden_reminder.#{signal}_title", plant: plant),
          body:       I18n.t("notification.garden_reminder.#{signal}_body", plant: plant, bed: bed),
          url:        "/garden_beds/#{planting.garden_bed_id}"
        ).previously_new_record?
      end
    end
  end
end
