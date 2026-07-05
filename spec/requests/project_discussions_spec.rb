# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "ProjectDiscussions" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }
  let(:project)    { create(:project, household:) }

  before { login_via_post(user) }

  it "opens, resolves and reopens a discussion" do
    post project_discussions_path(project), params: { project_discussion: { title: "Welcher Bodenbelag?" } }
    discussion = project.project_discussions.last
    expect(discussion.creator).to eq(user)
    expect(discussion.status).to eq("open")

    post resolve_project_discussion_path(project, discussion)
    expect(discussion.reload).to be_resolved
    expect(discussion.resolved_at).to be_present

    post reopen_project_discussion_path(project, discussion)
    expect(discussion.reload.status).to eq("open")
  end

  it "adds and removes comments" do
    discussion = create(:project_discussion, project:)
    post project_discussion_comments_path(discussion),
         params: { project_discussion_comment: { body: "Eiche, klar." } }
    comment = discussion.project_discussion_comments.last
    expect(comment.user).to eq(user)
    expect(comment.household).to eq(household)

    expect { delete project_discussion_comment_path(discussion, comment) }
      .to change(discussion.project_discussion_comments, :count).by(-1)
  end

  it "forbids comment deletion by non-author members" do
    discussion = create(:project_discussion, project:)
    comment = discussion.project_discussion_comments.create!(user: user, body: "Meins")

    member = create(:user)
    Membership.create!(user: member, household: household, role: "member")
    login_via_post(member)
    delete project_discussion_comment_path(discussion, comment)
    expect(discussion.project_discussion_comments.count).to eq(1)
  end

  it "404s for discussions of another household" do
    foreign = create(:project_discussion, project: create(:project, household: create(:household)))
    post project_discussion_comments_path(foreign),
         params: { project_discussion_comment: { body: "x" } }
    expect(response).to have_http_status(:not_found)
  end
end
