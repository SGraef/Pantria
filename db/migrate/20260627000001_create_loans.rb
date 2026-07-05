# frozen_string_literal: true

# Tracks borrowed/lent items: stuff we got from someone (direction "borrowed")
# and stuff we gave to someone ("lent"). counterparty_key is the normalized
# person name used to match outstanding loans against calendar-event titles for
# the "you're about to meet them" reminder (Reminders::LoanCalendarScanner).
class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.references :household, null: false, foreign_key: true
      t.string :item, null: false
      t.string :counterparty, null: false
      t.string :counterparty_key, null: false
      t.string :direction, null: false # borrowed | lent
      t.string :status, null: false, default: "outstanding" # outstanding | returned
      t.date   :loaned_on
      t.date   :due_on
      t.date   :returned_on
      t.text   :notes
      t.timestamps
    end

    add_index :loans, %i[household_id status]
    add_index :loans, %i[household_id counterparty_key]
  end
end
