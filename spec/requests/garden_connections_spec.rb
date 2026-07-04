# frozen_string_literal: true
# typed: false

require "rails_helper"

RSpec.describe "GardenConnections" do
  let(:admin)      { create(:user) }
  let!(:household) { create(:household, admin: admin) }

  describe "as an admin" do
    before { login_via_post(admin) }

    it "creates a connection with an encrypted key" do
      expect do
        post garden_connection_path, params: { garden_connection: { api_key: "secret-key", hardiness_zone: "8" } }
      end.to change(GardenConnection, :count).by(1)

      expect(response).to redirect_to(garden_connection_path)
      conn = household.reload.garden_connection
      expect(conn.api_key).to eq("secret-key")
      expect(conn.hardiness_zone).to eq("8")
    end

    it "keeps the stored key when the field is left blank on update" do
      create(:garden_connection, household: household, api_key: "keep-me")
      patch garden_connection_path, params: { garden_connection: { api_key: "", region: "NRW" } }

      conn = household.reload.garden_connection
      expect(conn.api_key).to eq("keep-me")
      expect(conn.region).to eq("NRW")
    end

    it "disconnects" do
      create(:garden_connection, household: household)
      expect { delete garden_connection_path }.to change(GardenConnection, :count).by(-1)
    end
  end

  describe "as a non-admin member" do
    let(:member) { create(:user) }

    before do
      create(:membership, user: member, household: household, role: "member")
      login_via_post(member)
    end

    it "is not authorized to configure the connection" do
      get new_garden_connection_path
      expect(response).to redirect_to(root_path)
    end
  end
end
