# frozen_string_literal: true
# typed: false

# The household plant catalog. Plants are cached locally (see {Plant}); the
# Perenual API is only touched on explicit search/import, so day-to-day the
# catalog works offline and within the free-tier rate limit.
class PlantsController < ApplicationController
  before_action :ensure_household
  before_action :set_plant, only: %i[show destroy]

  def index
    authorize Plant
    @plants = current_household.plants.ordered
    @connection = current_household.garden_connection
  end

  def show
    authorize @plant
  end

  # GET /plants/search?q= -- live Perenual lookup, rendered as importable results.
  def search
    authorize Plant
    @query = params[:q].to_s.strip
    @connection = current_household.garden_connection
    @results = []
    return if @query.blank?

    unless @connection&.connected?
      flash.now[:alert] = t("plant.connect_first")
      return
    end

    @results = Perenual::Client.new(@connection).search(@query)
  rescue Perenual::Error => e
    flash.now[:alert] = t("plant.search_failed", error: e.message)
  end

  # POST /plants/import -- add a searched species to the local catalog.
  def import
    authorize Plant
    connection = current_household.garden_connection
    plant = current_household.plants.find_or_initialize_by(perenual_id: import_params[:perenual_id])
    plant.assign_attributes(attributes_for_import(connection))

    if plant.save
      redirect_to plant_path(plant), notice: t("notices.plant_added")
    else
      redirect_to plants_path, alert: plant.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @plant
    @plant.destroy
    redirect_to plants_path, notice: t("notices.plant_removed")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_plant
    @plant = current_household.plants.find(params[:id])
  end

  def import_params
    params.permit(:perenual_id, :common_name, :scientific_name, :cycle, :image_url)
  end

  # Prefer authoritative Perenual details; fall back to the summary the search
  # result carried if the details call fails (rate limit / transient error), so
  # importing still works.
  def attributes_for_import(connection)
    base = import_params.to_h.symbolize_keys.slice(:common_name, :scientific_name, :cycle, :image_url)
    return base unless connection&.connected? && import_params[:perenual_id].present?

    d = Perenual::Client.new(connection).details(import_params[:perenual_id])
    base.merge(
      common_name: d.common_name.presence || base[:common_name],
      scientific_name: d.scientific_name.presence || base[:scientific_name],
      cycle: d.cycle, sunlight: d.sunlight, watering: d.watering,
      hardiness_min: d.hardiness_min, hardiness_max: d.hardiness_max,
      edible: d.edible, image_url: d.image_url.presence || base[:image_url],
      external_url: d.external_url
    ).compact
  rescue Perenual::Error
    base
  end
end
