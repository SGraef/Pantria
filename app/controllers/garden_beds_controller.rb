# frozen_string_literal: true
# typed: false

# CRUD for garden beds. The show page doubles as the planner for that bed:
# it lists its plantings and offers the "add a plant here" form.
class GardenBedsController < ApplicationController
  before_action :ensure_household
  before_action :set_bed, only: %i[show edit update destroy geometry]

  def index
    @garden_beds = current_household.garden_beds.ordered
  end

  def show
    authorize @bed
    @plantings = @bed.plantings.includes(:plant).ordered
    @plants = current_household.plants.ordered
  end

  def new
    @bed = current_household.garden_beds.build
    authorize @bed
  end

  def edit
    authorize @bed
  end

  def create
    @bed = current_household.garden_beds.build(bed_params)
    authorize @bed
    if @bed.save
      redirect_to garden_bed_path(@bed), notice: t("notices.garden_bed_added")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @bed
    if @bed.update(bed_params)
      redirect_to garden_bed_path(@bed), notice: t("notices.garden_bed_updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @bed
    @bed.destroy
    redirect_to garden_beds_path, notice: t("notices.garden_bed_removed")
  end

  # JSON endpoint the garden planner saves dimensions/position through.
  # Responds with the server-computed area so the client can display it.
  def geometry
    authorize @bed, :update?
    if @bed.update(geometry_params)
      render json: { area_sqm: @bed.area_sqm&.to_f }
    else
      render json: { errors: @bed.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_bed
    @bed = current_household.garden_beds.find(params[:id])
  end

  def bed_params
    params.require(:garden_bed).permit(:name, :location, :sun_exposure, :notes)
  end

  def geometry_params
    params.require(:garden_bed).permit(:width_m, :length_m, :pos_x_m, :pos_y_m)
  end
end
