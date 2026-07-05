# frozen_string_literal: true
# typed: false

# Typed links between two projects (blocked_by | related). The related
# project is looked up through the household so foreign ids 404.
class ProjectRelationsController < ApplicationController
  before_action :ensure_household
  before_action :set_project

  def create
    related = current_household.projects.find(relation_params[:related_project_id])
    @relation = @project.relations.build(kind: relation_params[:kind], related_project: related)
    authorize @relation
    if @relation.save
      redirect_to project_path(@project, anchor: "relations"),
                  notice: t("notices.project_relation_added")
    else
      redirect_to project_path(@project), alert: @relation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @relation = @project.relations.find(params[:id])
    authorize @relation
    @relation.destroy
    redirect_to project_path(@project, anchor: "relations"),
                notice: t("notices.project_relation_removed")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_project
    @project = current_household.projects.find(params[:project_id])
  end

  def relation_params
    params.require(:project_relation).permit(:kind, :related_project_id)
  end
end
