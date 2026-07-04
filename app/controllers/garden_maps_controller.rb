# frozen_string_literal: true
# typed: false

# The visual garden overview. `show` renders either the Leaflet map over
# official WMS layers or the abstract lite planner, per the household's
# {GardenMapSetting}; `update` is the admin-only settings form on that page.
# Bed geometry itself is saved via GardenBedsController#geometry.
class GardenMapsController < ApplicationController
  before_action :ensure_household
  before_action :set_settings

  def show
    authorize @settings, :show?
    @garden_beds = current_household.garden_beds.includes(plantings: :plant).ordered
  end

  def update
    authorize @settings
    if @settings.update(settings_params)
      redirect_to garden_map_path, notice: t("notices.garden_map_settings_saved")
    else
      @garden_beds = current_household.garden_beds.includes(plantings: :plant).ordered
      render :show, status: :unprocessable_content
    end
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  # Built in memory (not persisted) until the admin saves the form once, so
  # the map works out of the box with the Niedersachsen defaults.
  def set_settings
    @settings = current_household.garden_map_setting ||
                current_household.build_garden_map_setting
  end

  def settings_params
    params.require(:garden_map_setting).permit(
      :mode, :bundesland, :center_lat, :center_lng, :zoom,
      :custom_dop_url, :custom_dop_layer, :custom_alkis_url, :custom_alkis_layer
    )
  end
end
