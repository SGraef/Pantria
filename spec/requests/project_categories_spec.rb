# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "ProjectCategories" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  it "lists, creates, updates and removes categories" do
    post project_categories_path, params: { project_category: { name: "Renovierung", color: "clay" } }
    category = household.project_categories.find_by!(name: "Renovierung")

    get project_categories_path
    expect(response.body).to include("Renovierung")

    patch project_category_path(category), params: { project_category: { name: "Umbau" } }
    expect(category.reload.name).to eq("Umbau")

    expect { delete project_category_path(category) }
      .to change(household.project_categories, :count).by(-1)
  end

  it "uncategorizes projects when their category is removed" do
    category = create(:project_category, household:)
    project = create(:project, household:, project_category: category)
    delete project_category_path(category)
    expect(project.reload.project_category_id).to be_nil
  end

  it "rejects non-palette colors" do
    post project_categories_path, params: { project_category: { name: "X", color: "neon" } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
