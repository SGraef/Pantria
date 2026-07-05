# frozen_string_literal: true
# typed: false

# CRUD for the household's project categories (colored chips on the kanban
# cards). Offer categories pattern; deleting one just uncategorizes its
# projects (dependent: :nullify on the model).
class ProjectCategoriesController < ApplicationController
  before_action :ensure_household
  before_action :set_category, only: %i[update destroy]

  def index
    @categories = current_household.project_categories.ordered
    @new_category = current_household.project_categories.new(position: next_position)
  end

  def create
    @category = current_household.project_categories.new(category_params)
    @category.position = next_position if @category.position.to_i.zero?

    if @category.save
      redirect_to project_categories_path,
                  notice: t("project.categories.flash.created", name: @category.name)
    else
      flash.now[:alert] = @category.errors.full_messages.to_sentence
      @categories = current_household.project_categories.ordered
      @new_category = @category
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @category.update(category_params)
      redirect_to project_categories_path,
                  notice: t("project.categories.flash.updated", name: @category.name)
    else
      redirect_to project_categories_path, alert: @category.errors.full_messages.to_sentence
    end
  end

  def destroy
    @category.destroy
    redirect_to project_categories_path,
                notice: t("project.categories.flash.removed", name: @category.name)
  end

  private

  def ensure_household
    redirect_to root_path, alert: t("flash.create_household_first") unless current_household
  end

  def set_category
    @category = current_household.project_categories.find(params[:id])
  end

  def category_params
    params.require(:project_category).permit(:name, :position, :color)
  end

  def next_position
    (current_household.project_categories.maximum(:position) || 0) + 10
  end
end
