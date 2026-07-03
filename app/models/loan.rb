# frozen_string_literal: true
# typed: false

# A borrowed or lent item -- something we got from someone ("borrowed") or gave
# to someone ("lent"). Outstanding loans are matched against calendar-event
# titles by the person's name so we can remind "you're meeting them, bring it"
# (see Reminders::LoanCalendarScanner).
class Loan < ApplicationRecord
  DIRECTIONS = %w[borrowed lent].freeze
  STATUSES   = %w[outstanding returned].freeze

  belongs_to :household

  validates :item, presence: true, length: { maximum: 200 }
  validates :counterparty, presence: true, length: { maximum: 200 }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_counterparty_key

  scope :outstanding, -> { where(status: "outstanding") }
  scope :returned,    -> { where(status: "returned") }
  scope :borrowed,    -> { where(direction: "borrowed") }
  scope :lent,        -> { where(direction: "lent") }
  scope :ordered,     -> { order(status: :asc, due_on: :asc, created_at: :desc) }

  # Mark the item handed back (returned by us if borrowed, returned to us if lent).
  def mark_returned!
    update!(status: "returned", returned_on: Date.current)
  end

  def reopen!
    update!(status: "outstanding", returned_on: nil)
  end

  def returned?
    status == "returned"
  end

  # Normalized form used both to store counterparty_key and to scan event titles
  # (transliterated + downcased so "Müller" matches "mueller"/"muller").
  def self.normalize(name)
    I18n.transliterate(name.to_s).downcase.strip
  end

  private

  def set_counterparty_key
    self.counterparty_key = self.class.normalize(counterparty)
  end
end
