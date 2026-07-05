# frozen_string_literal: true
# typed: false

# Household project planning. `index` is the kanban board (one column per
# user-defined status); `show` is the project workspace with materials,
# plans, discussions, attached todos and relations. `move` serves the
# board's drag & drop and its no-JS fallback form.
class ProjectsController < ApplicationController
  before_action :ensure_household
  before_action :ensure_statuses, only: %i[index new create]
  before_action :set_project, only: %i[show edit update destroy move]

  def index
    @statuses = current_household.project_statuses.ordered
    load_board
  end

  def show
    authorize @project
    @materials   = @project.materials.with_attached_file
    @plans       = @project.plans.with_attached_file
    @discussions = @project.project_discussions.includes(project_discussion_comments: :user)
    @todos       = @project.todos.includes(:assignee).order(:status, :due_on)
    @children    = @project.children.includes(:project_status).ordered
    @actual_cost_cents = @project.actual_cost_cents
  end

  def new
    @project = current_household.projects.build(project_status: default_status,
                                                parent_id:      params[:parent_id])
    authorize @project
  end

  def edit
    authorize @project
  end

  def create
    @project = current_household.projects.build(project_params)
    @project.creator = current_user
    @project.project_status ||= default_status
    @project.position = next_position(@project.project_status)
    authorize @project
    if @project.save
      redirect_to project_path(@project), notice: t("notices.project_created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to project_path(@project), notice: t("notices.project_updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: t("notices.project_removed")
  end

  # Board move: change column (status) and/or position within it. The whole
  # target column is renumbered in one transaction -- columns are household-
  # sized, and a full renumber can't run out of gaps. A missing position
  # appends (the no-JS fallback form sends only the status).
  def move
    authorize @project
    status = current_household.project_statuses.find(move_params[:project_status_id])
    @source_status = @project.project_status
    @target_status = status

    Project.transaction do
      column = current_household.projects.where(project_status: status)
                                .where.not(id: @project.id).order(:position).lock.to_a
      index = move_params[:position].presence&.to_i&.clamp(0, column.size) || column.size
      column.insert(index, @project)
      @project.update!(project_status: status)
      column.each_with_index { |p, i| p.update_column(:position, (i + 1) * 10) }
    end

    @statuses = current_household.project_statuses.ordered
    load_board
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to projects_path }
    end
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  # Backfills households that predate the projects feature (the seeder is
  # idempotent; new households get statuses via after_create).
  def ensure_statuses
    ProjectStatusSeeder.call(current_household)
  end

  def set_project
    @project = current_household.projects.find(params[:id])
  end

  def default_status
    current_household.project_statuses.ordered.first
  end

  def next_position(status)
    (current_household.projects.where(project_status: status).maximum(:position) || 0) + 10
  end

  # Everything the board needs, precomputed in grouped queries (no counter
  # caches by repo convention).
  def load_board
    @projects = current_household.projects.includes(:project_category).ordered.to_a
    ids = @projects.map(&:id)
    @costs = Project.actual_costs_by_id(@projects)
    @open_todo_counts = current_household.todos.active.where(project_id: ids)
                                         .group(:project_id).count
    @open_discussion_counts = ProjectDiscussion.where(project_id: ids).open_state
                                               .group(:project_id).count
    @blocked_ids = ProjectRelation.where(kind: "blocked_by", project_id: ids)
                                  .joins(related_project: :project_status)
                                  .where(project_statuses: { done: false })
                                  .distinct.pluck(:project_id).to_set
    @children_counts = current_household.projects.where.not(parent_id: nil)
                                        .group(:parent_id).count
  end

  def project_params
    params.require(:project).permit(:name, :description, :project_status_id,
                                    :project_category_id, :parent_id, :budget)
  end

  def move_params
    params.require(:project).permit(:project_status_id, :position)
  end
end
