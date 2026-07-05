# frozen_string_literal: true
# typed: false

# Plantings: a plant placed in a bed. Created/edited from the bed's page; the
# one-tap "advance" walks the lifecycle planned -> sown -> growing -> harvested,
# stamping the matching date so the reminders and journal stay accurate.
class PlantingsController < ApplicationController
  before_action :ensure_household
  before_action :set_planting, only: %i[update destroy advance]

  def create
    @planting = current_household.plantings.build(create_params)
    authorize @planting
    if @planting.save
      redirect_to garden_bed_path(@planting.garden_bed), notice: t("notices.planting_added")
    else
      redirect_to garden_bed_path(params.dig(:planting, :garden_bed_id)),
                  alert: @planting.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @planting
    if @planting.update(update_params)
      redirect_to garden_bed_path(@planting.garden_bed), notice: t("notices.planting_updated")
    else
      redirect_to garden_bed_path(@planting.garden_bed),
                  alert: @planting.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @planting
    bed = @planting.garden_bed
    @planting.destroy
    redirect_to garden_bed_path(bed), notice: t("notices.planting_removed")
  end

  # POST /plantings/:id/advance -- move to the next lifecycle stage.
  def advance
    authorize @planting, :update?
    advance_status!(@planting)
    redirect_to garden_bed_path(@planting.garden_bed), notice: t("notices.planting_updated")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_planting
    @planting = current_household.plantings.find(params[:id])
  end

  def create_params
    params.require(:planting).permit(:garden_bed_id, :plant_id, :quantity, :notes)
  end

  def update_params
    params.require(:planting).permit(:quantity, :status, :sown_on, :planted_out_on,
                                     :expected_harvest_on, :harvested_on, :notes)
  end

  # Walk to the next status and stamp the date that stage implies.
  def advance_status!(planting)
    case planting.status
    when "planned"  then planting.update(status: "sown", sown_on: Date.current)
    when "sown"     then planting.update(status: "growing", planted_out_on: Date.current)
    when "growing"  then planting.update(status: "harvested", harvested_on: Date.current)
    end
  end
end
