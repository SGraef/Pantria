# frozen_string_literal: true
# typed: false

# Comments under a project discussion (todo_comments pattern, without the
# turbo broadcasts -- plain POST + redirect keeps v1 simple).
class ProjectDiscussionCommentsController < ApplicationController
  before_action :ensure_household
  before_action :set_discussion

  def create
    @comment = @discussion.project_discussion_comments.build(comment_params)
    @comment.user = current_user
    authorize @comment
    if @comment.save
      redirect_to project_path(@discussion.project, anchor: "discussions"),
                  notice: t("notices.project_comment_added")
    else
      redirect_to project_path(@discussion.project),
                  alert: @comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @comment = @discussion.project_discussion_comments.find(params[:id])
    authorize @comment
    @comment.destroy
    redirect_to project_path(@discussion.project, anchor: "discussions"),
                notice: t("notices.project_comment_removed")
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_discussion
    @discussion = ProjectDiscussion.where(household: current_household)
                                   .find(params[:project_discussion_id])
  end

  def comment_params
    params.require(:project_discussion_comment).permit(:body)
  end
end
