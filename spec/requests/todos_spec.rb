# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "Todos" do
  let(:admin)      { create(:user) }
  let!(:household) { create(:household, admin: admin) }

  before { login_via_post(admin) }

  describe "CRUD + listing" do
    it "lists todos" do
      todo = create(:todo, household: household, title: "Buy milk")
      get todos_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Buy milk")
      expect(todo).to be_persisted
    end

    it "creates a todo with the current user as creator" do
      expect { post todos_path, params: { todo: { title: "Fix the sink" } } }
        .to change(Todo, :count).by(1)
      todo = Todo.last
      expect(todo.title).to eq("Fix the sink")
      expect(todo.creator).to eq(admin)
      expect(todo.status).to eq("open")
    end

    it "attaches a todo to a project of the household" do
      project = create(:project, household: household)
      post todos_path, params: { todo: { title: "Bretter kaufen", project_id: project.id } }
      expect(Todo.last.project).to eq(project)
    end

    it "rejects a project from another household" do
      foreign = create(:project, household: create(:household))
      post todos_path, params: { todo: { title: "X", project_id: foreign.id } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /todos/:id/transition" do
    it "applies a legal transition and sets completed_at on done" do
      todo = create(:todo, household: household, status: "in_progress")
      post transition_todo_path(todo, to: "done")
      expect(todo.reload.status).to eq("done")
      expect(todo.completed_at).to be_present
    end

    it "rejects an illegal transition with an alert" do
      todo = create(:todo, household: household, status: "open")
      post transition_todo_path(todo, to: "done")
      expect(todo.reload.status).to eq("open")
      expect(flash[:alert]).to be_present
    end
  end

  describe "destroy authorization" do
    it "lets an admin delete a todo" do
      todo = create(:todo, household: household)
      expect { delete todo_path(todo) }.to change(Todo, :count).by(-1)
    end

    it "denies a non-admin member" do
      member = create(:user)
      Membership.create!(user: member, household: household, role: "member")
      todo = create(:todo, household: household)

      login_via_post(member)
      expect { delete todo_path(todo) }.not_to change(Todo, :count)
    end
  end

  describe "comments" do
    it "adds a comment to a todo" do
      todo = create(:todo, household: household)
      expect { post todo_comments_path(todo), params: { todo_comment: { body: "On it" } } }
        .to change { todo.todo_comments.count }.by(1)
      expect(todo.todo_comments.last.user).to eq(admin)
    end
  end
end
