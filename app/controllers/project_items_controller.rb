# frozen_string_literal: true
# typed: false

# Materials and plans of a project (one controller for both kinds). Created
# and edited inline on the project page; each item can carry a link, an
# uploaded file and a cost.
class ProjectItemsController < ApplicationController
  before_action :ensure_household
  before_action :set_project
  before_action :set_item, only: %i[update destroy]

  def create
    @item = @project.project_items.build(item_params)
    authorize @item
    if @item.save
      redirect_to project_path(@project, anchor: anchor_for(@item)),
                  notice: t("notices.project_item_added")
    else
      redirect_to project_path(@project), alert: @item.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @item
    if @item.update(item_params)
      redirect_to project_path(@project, anchor: anchor_for(@item)),
                  notice: t("notices.project_item_updated")
    else
      redirect_to project_path(@project), alert: @item.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @item
    @item.destroy
    redirect_to project_path(@project), notice: t("notices.project_item_removed")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_project
    @project = current_household.projects.find(params[:project_id])
  end

  def set_item
    @item = @project.project_items.find(params[:id])
  end

  def item_params
    params.require(:project_item).permit(:kind, :name, :url, :cost, :notes, :file)
  end

  def anchor_for(item)
    item.kind == "plan" ? "plans" : "materials"
  end
end
