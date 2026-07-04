# frozen_string_literal: true
# typed: false

# Connect / edit / disconnect flow for a household's Perenual API key (admin
# only, see {GardenConnectionPolicy}). The key is stored encrypted; the form
# never echoes it back.
class GardenConnectionsController < ApplicationController
  before_action :ensure_household
  before_action :set_connection, only: %i[show update destroy]
  before_action :authorize_connection

  def show
    redirect_to(new_garden_connection_path) unless @connection
  end

  def new
    @connection = current_household.garden_connection || current_household.build_garden_connection
  end

  def create
    @connection = current_household.garden_connection || current_household.build_garden_connection
    @connection.assign_attributes(connection_params)

    if @connection.save
      redirect_to garden_connection_path, notice: t("garden_connection.saved")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    return redirect_to(new_garden_connection_path) unless @connection

    # Leave the stored key untouched when the field is submitted blank, so an
    # admin can tweak the zone/region without re-entering the secret.
    attrs = connection_params
    attrs = attrs.except(:api_key) if attrs[:api_key].blank?

    if @connection.update(attrs)
      redirect_to garden_connection_path, notice: t("garden_connection.saved")
    else
      render :show, status: :unprocessable_content
    end
  end

  def destroy
    @connection&.destroy
    redirect_to garden_connection_path, notice: t("garden_connection.disconnected")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_connection
    @connection = current_household.garden_connection
  end

  def authorize_connection
    authorize(@connection || GardenConnection.new(household: current_household))
  end

  def connection_params
    params.require(:garden_connection).permit(:api_key, :hardiness_zone, :region)
  end
end
