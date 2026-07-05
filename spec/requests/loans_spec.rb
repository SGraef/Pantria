# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "Loans" do
  let(:user)       { create(:user) }
  let!(:household) { create(:household, admin: user) }

  before { login_via_post(user) }

  describe "GET /loans" do
    it "lists outstanding loans and hides returned ones by default" do
      create(:loan, household: household, item: "Cordless drill", counterparty: "Anna")
      create(:loan, :returned, household: household, item: "Ladder", counterparty: "Bob")

      get loans_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cordless drill")
      expect(response.body).not_to include("Ladder")
    end

    it "includes returned loans when asked" do
      create(:loan, :returned, household: household, item: "Ladder", counterparty: "Bob")
      get loans_path(show_returned: 1)
      expect(response.body).to include("Ladder")
    end
  end

  describe "GET /loans/:id" do
    it "shows a single loan" do
      loan = create(:loan, household: household, item: "Cordless drill", counterparty: "Anna")
      get loan_path(loan)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cordless drill")
      expect(response.body).to include("Anna")
    end
  end

  describe "GET /loans/new" do
    it "preselects the direction from the entry point" do
      get new_loan_path(direction: "lent")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<option selected="selected" value="lent">')
    end
  end

  describe "POST /loans" do
    it "creates a loan and normalizes the counterparty key" do
      expect do
        post loans_path, params: { loan: {
          direction: "borrowed", item: "Tent", counterparty: "Anna Müller", loaned_on: "2026-06-01"
        } }
      end.to change(Loan, :count).by(1)

      expect(response).to redirect_to(loans_path)
      expect(Loan.last.counterparty_key).to eq("anna muller")
    end

    it "re-renders on invalid input" do
      post loans_path, params: { loan: { direction: "borrowed", item: "", counterparty: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "attaches an uploaded photo" do
      photo = Rack::Test::UploadedFile.new(StringIO.new("fake-jpeg"), "image/jpeg", original_filename: "drill.jpg")
      post loans_path, params: { loan: {
        direction: "borrowed", item: "Drill", counterparty: "Anna", photo: photo
      } }

      expect(response).to redirect_to(loans_path)
      expect(Loan.last.photo).to be_attached
    end
  end

  describe "member actions" do
    let(:loan) { create(:loan, household: household) }

    it "marks a loan returned and reopens it" do
      post mark_returned_loan_path(loan)
      expect(response).to redirect_to(loans_path)
      expect(loan.reload).to be_returned

      post reopen_loan_path(loan)
      expect(loan.reload).not_to be_returned
    end

    it "updates and deletes a loan" do
      patch loan_path(loan), params: { loan: { item: "Renamed" } }
      expect(loan.reload.item).to eq("Renamed")

      expect { delete loan_path(loan) }.to change(Loan, :count).by(-1)
    end
  end
end
