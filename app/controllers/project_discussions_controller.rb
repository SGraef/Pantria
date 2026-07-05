# frozen_string_literal: true
# typed: false

# Discussion threads on a project: open, resolve, reopen, remove. Comments
# live in ProjectDiscussionCommentsController.
class ProjectDiscussionsController < ApplicationController
  before_action :ensure_household
  before_action :set_project
  before_action :set_discussion, only: %i[resolve reopen destroy]

  def create
    @discussion = @project.project_discussions.build(discussion_params)
    @discussion.creator = current_user
    authorize @discussion
    if @discussion.save
      redirect_to project_path(@project, anchor: "discussions"),
                  notice: t("notices.project_discussion_added")
    else
      redirect_to project_path(@project), alert: @discussion.errors.full_messages.to_sentence
    end
  end

  def resolve
    authorize @discussion
    @discussion.resolve!
    redirect_to project_path(@project, anchor: "discussions"),
                notice: t("notices.project_discussion_resolved")
  end

  def reopen
    authorize @discussion
    @discussion.reopen!
    redirect_to project_path(@project, anchor: "discussions"),
                notice: t("notices.project_discussion_reopened")
  end

  def destroy
    authorize @discussion
    @discussion.destroy
    redirect_to project_path(@project, anchor: "discussions"),
                notice: t("notices.project_discussion_removed")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_project
    @project = current_household.projects.find(params[:project_id])
  end

  def set_discussion
    @discussion = @project.project_discussions.find(params[:id])
  end

  def discussion_params
    params.require(:project_discussion).permit(:title)
  end
end
