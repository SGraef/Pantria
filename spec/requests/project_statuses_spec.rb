# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "ProjectStatuses" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  describe "GET /projects/statuses" do
    it "lists the seeded defaults" do
      get project_statuses_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Idee", "Erledigt")
    end
  end

  describe "POST /projects/statuses" do
    it "creates a status appended at the end" do
      expect do
        post project_statuses_path, params: { project_status: { name: "Wartet", color: "sky" } }
      end.to change(household.project_statuses, :count).by(1)
      expect(household.project_statuses.ordered.last.name).to eq("Wartet")
    end

    it "rejects duplicate names" do
      post project_statuses_path, params: { project_status: { name: "idee" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /projects/statuses/:id" do
    it "updates name, color and done flag" do
      status = household.project_statuses.find_by(name: "Idee")
      patch project_status_path(status), params: { project_status: { name: "Brainstorm", done: true } }
      expect(status.reload.name).to eq("Brainstorm")
      expect(status).to be_done
    end
  end

  describe "DELETE /projects/statuses/:id" do
    it "refuses while projects use the status" do
      project = create(:project, household:)
      delete project_status_path(project.project_status)
      expect(flash[:alert]).to eq(I18n.t("project.statuses.flash.in_use", name: project.project_status.name))
      expect(household.project_statuses.count).to eq(4)
    end

    it "refuses to remove the last status" do
      household.project_statuses.ordered.to_a[0..2].each(&:destroy!)
      delete project_status_path(household.project_statuses.first)
      expect(flash[:alert]).to eq(I18n.t("project.statuses.flash.last_status"))
      expect(household.project_statuses.count).to eq(1)
    end

    it "removes an unused status" do
      status = household.project_statuses.find_by(name: "Idee")
      expect { delete project_status_path(status) }.to change(household.project_statuses, :count).by(-1)
    end
  end

  describe "POST /projects/statuses/reset_defaults" do
    it "re-seeds when no projects exist" do
      household.project_statuses.find_by(name: "Idee").update!(name: "Weird")
      post reset_defaults_project_statuses_path
      expect(household.project_statuses.ordered.pluck(:name))
        .to eq(["Idee", "Geplant", "In Arbeit", "Erledigt"])
    end

    it "refuses while projects exist" do
      create(:project, household:)
      post reset_defaults_project_statuses_path
      expect(flash[:alert]).to eq(I18n.t("project.statuses.flash.reset_blocked"))
    end
  end
end
