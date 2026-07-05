# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "Projects" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  describe "GET /projects (the board)" do
    it "renders a column per status with card metrics" do
      project = create(:project, household:, name: "Dachboden dämmen", budget: "100.00")
      create(:project_item, project:, cost: "150.00")
      create(:project_discussion, project:)
      create(:todo, household:, project:)
      blocker = create(:project, household:, name: "Elektrik erneuern")
      create(:project_relation, project:, related_project: blocker, kind: "blocked_by")

      get projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dachboden dämmen")
      household.project_statuses.each { |s| expect(response.body).to include(s.name) }
      expect(response.body).to include(I18n.t("project.card.blocked"))
      expect(response.body).to include(I18n.t("project.card.open_todos", count: 1))
      expect(response.body).to include(I18n.t("project.card.open_discussions", count: 1))
    end

    it "lazily seeds statuses for a household that predates the feature" do
      household.project_statuses.destroy_all
      get projects_path
      expect(response).to have_http_status(:ok)
      expect(household.project_statuses.count).to eq(4)
    end
  end

  describe "CRUD" do
    it "creates a project with budget and category" do
      category = create(:project_category, household:)
      expect do
        post projects_path, params: { project: {
          name: "Zaun bauen", budget: "250.50", project_category_id: category.id,
          project_status_id: household.project_statuses.ordered.first.id
        } }
      end.to change(Project, :count).by(1)
      project = Project.last
      expect(project.budget_cents).to eq(25_050)
      expect(project.creator).to eq(user)
    end

    it "creates a subproject via parent_id and shows it on the parent page" do
      parent = create(:project, household:)
      post projects_path, params: { project: {
        name: "Teilstück", parent_id: parent.id,
        project_status_id: household.project_statuses.ordered.first.id
      } }
      expect(Project.last.parent).to eq(parent)

      get project_path(parent)
      expect(response.body).to include("Teilstück")
    end

    it "rejects a parent from another household" do
      foreign = create(:project, household: create(:household))
      post projects_path, params: { project: {
        name: "X", parent_id: foreign.id,
        project_status_id: household.project_statuses.ordered.first.id
      } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows costs, relations and discussions on the project page" do
      project = create(:project, household:, budget: "10.00")
      create(:project_item, project:, cost: "25.00", name: "Bretter")
      get project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bretter")
      expect(response.body).to include(I18n.t("project.card.over_budget"))
    end

    it "destroy is admin-only and keeps todos + children" do
      project = create(:project, household:)
      todo = create(:todo, household:, project:)
      child = create(:project, household:, parent: project)

      member = create(:user)
      Membership.create!(user: member, household: household, role: "member")
      login_via_post(member)
      delete project_path(project)
      expect(Project.exists?(project.id)).to be(true)

      login_via_post(user)
      expect { delete project_path(project) }.to change(Project, :count).by(-1)
      expect(todo.reload.project_id).to be_nil
      expect(child.reload.parent_id).to be_nil
    end
  end

  describe "PATCH /projects/:id/move (no-JS fallback)" do
    it "moves the project to the target column, appending at the end" do
      target = household.project_statuses.ordered.second
      sitting = create(:project, household:, project_status: target, position: 10)
      project = create(:project, household:)

      patch move_project_path(project), params: { project: { project_status_id: target.id } }
      expect(response).to redirect_to(projects_path)
      expect(project.reload.project_status).to eq(target)
      expect(project.position).to be > sitting.reload.position
    end

    it "404s for a status of another household" do
      project = create(:project, household:)
      foreign = create(:household).project_statuses.first
      patch move_project_path(project), params: { project: { project_status_id: foreign.id } }
      expect(response).to have_http_status(:not_found)
    end
  end
end
