# frozen_string_literal: true
# typed: false

# CRUD for borrowed/lent item tracking. Outstanding loans drive the
# calendar-meeting reminder (Reminders::LoanCalendarScanner).
class LoansController < ApplicationController
  before_action :ensure_household
  before_action :set_loan, only: %i[show edit update destroy mark_returned reopen]

  def index
    @show_returned = params[:show_returned] == "1"
    scope = current_household.loans.ordered
    scope = scope.outstanding unless @show_returned
    @loans = scope
    @returned_count = current_household.loans.returned.count
  end

  def show
    authorize @loan
  end

  def new
    @loan = current_household.loans.build(direction: direction_param, loaned_on: Date.current)
    authorize @loan
  end

  def edit
    authorize @loan
  end

  def create
    @loan = current_household.loans.build(loan_params)
    authorize @loan
    if @loan.save
      redirect_to loans_path, notice: t("notices.loan_added")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @loan
    if @loan.update(loan_params)
      redirect_to loans_path, notice: t("notices.loan_updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @loan
    @loan.destroy
    redirect_to loans_path, notice: t("notices.loan_removed")
  end

  # POST /loans/:id/mark_returned -- the item changed hands back.
  def mark_returned
    authorize @loan, :update?
    @loan.mark_returned!
    redirect_to loans_path, notice: t("notices.loan_returned")
  end

  # POST /loans/:id/reopen -- it's out again.
  def reopen
    authorize @loan, :update?
    @loan.reopen!
    redirect_to loans_path, notice: t("notices.loan_reopened")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_loan
    @loan = current_household.loans.find(params[:id])
  end

  def loan_params
    params.require(:loan).permit(:item, :counterparty, :direction, :loaned_on, :due_on, :notes, :photo)
  end

  def direction_param
    Loan::DIRECTIONS.include?(params[:direction]) ? params[:direction] : "borrowed"
  end
end
