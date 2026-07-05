# frozen_string_literal: true
# typed: false

# CRUD for the household's project statuses -- the kanban columns. Index is
# the one-stop edit surface (offer categories pattern): list, add, rename,
# recolor, reorder by position, mark as done-status, delete, reset.
#
# Deletion is guarded: a status that still has projects, or the household's
# last remaining status, must stay (projects.project_status_id is NOT NULL).
class ProjectStatusesController < ApplicationController
  before_action :ensure_household
  before_action :set_status, only: %i[update destroy]

  def index
    @statuses = current_household.project_statuses.ordered
    @new_status = current_household.project_statuses.new(position: next_position)
  end

  def create
    @status = current_household.project_statuses.new(status_params)
    @status.position = next_position if @status.position.to_i.zero?

    if @status.save
      redirect_to project_statuses_path,
                  notice: t("project.statuses.flash.created", name: @status.name)
    else
      flash.now[:alert] = @status.errors.full_messages.to_sentence
      @statuses = current_household.project_statuses.ordered
      @new_status = @status
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @status.update(status_params)
      redirect_to project_statuses_path,
                  notice: t("project.statuses.flash.updated", name: @status.name)
    else
      redirect_to project_statuses_path, alert: @status.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @status.projects.exists?
      redirect_to project_statuses_path, alert: t("project.statuses.flash.in_use", name: @status.name)
    elsif current_household.project_statuses.where.not(id: @status.id).none?
      redirect_to project_statuses_path, alert: t("project.statuses.flash.last_status")
    else
      @status.destroy
      redirect_to project_statuses_path,
                  notice: t("project.statuses.flash.removed", name: @status.name)
    end
  end

  # POST /projects/statuses/reset_defaults
  # Refused while projects exist: replacing would strand their NOT NULL
  # status references. Guarded with a turbo-confirm in the view.
  def reset_defaults
    if current_household.projects.exists?
      redirect_to project_statuses_path, alert: t("project.statuses.flash.reset_blocked")
    else
      n = ProjectStatusSeeder.call(current_household, replace: true)
      redirect_to project_statuses_path, notice: t("project.statuses.flash.reset_done", count: n)
    end
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_status
    @status = current_household.project_statuses.find(params[:id])
  end

  def status_params
    params.require(:project_status).permit(:name, :position, :color, :done)
  end

  def next_position
    (current_household.project_statuses.maximum(:position) || 0) + 10
  end
end
