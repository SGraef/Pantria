# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "ProjectItems" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }
  let(:project)    { create(:project, household:) }

  before { login_via_post(user) }

  it "creates a material with a file upload and cost" do
    file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf",
                                        original_filename: "angebot.pdf")
    expect do
      post project_items_path(project), params: { project_item: {
        kind: "material", name: "Dämmwolle", cost: "89.90", file: file
      } }
    end.to change(project.project_items, :count).by(1)

    item = project.project_items.last
    expect(item.file).to be_attached
    expect(item.cost_cents).to eq(8990)
    expect(project.reload.own_cost_cents).to eq(8990)
  end

  it "creates a link-only plan" do
    post project_items_path(project), params: { project_item: {
      kind: "plan", name: "Skizze", url: "https://example.de/plan"
    } }
    item = project.project_items.last
    expect(item.kind).to eq("plan")
    expect(item.url).to eq("https://example.de/plan")
    expect(item.file).not_to be_attached
  end

  it "rejects disallowed file types" do
    file = Rack::Test::UploadedFile.new(StringIO.new("MZ"), "application/x-msdownload",
                                        original_filename: "virus.exe")
    post project_items_path(project), params: { project_item: { kind: "material", name: "X", file: file } }
    expect(response).to redirect_to(project_path(project))
    expect(flash[:alert]).to be_present
    expect(project.project_items.count).to eq(0)
  end

  it "updates and removes items" do
    item = create(:project_item, project:, cost: "10.00")
    patch project_item_path(project, item), params: { project_item: { cost: "12.50" } }
    expect(item.reload.cost_cents).to eq(1250)

    expect { delete project_item_path(project, item) }
      .to change(project.project_items, :count).by(-1)
  end

  it "404s for items of another household's project" do
    foreign = create(:project, household: create(:household))
    post project_items_path(foreign), params: { project_item: { kind: "material", name: "X" } }
    expect(response).to have_http_status(:not_found)
  end
end
