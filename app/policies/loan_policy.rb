# frozen_string_literal: true
# typed: true

# Loans are shared household data; any member can manage them (same posture as
# the grocery list / todos).
class LoanPolicy < ApplicationPolicy
  def destroy?       = household_member?
  def mark_returned? = household_member?
  def reopen?        = household_member?
end
