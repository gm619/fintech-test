# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::AccountsController, type: :request do
  let(:user) { create(:user) }
  let!(:account) { user.account }

  before do
    account.update!(balance: Money.new(500_00))
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
    allow_any_instance_of(AccountPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(AccountPolicy).to receive(:transactions?).and_return(true)
  end

  describe "GET /api/v1/account" do
    it "returns the account balance" do
      get "/api/v1/account", as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["balance"]["cents"]).to eq(500_00)
      expect(body["user_email"]).to eq(user.email)
    end
  end

  describe "GET /api/v1/account/transactions" do
    let!(:order) { create(:order, user: user, status: "created") }

    before do
      account.credit!(Money.new(200_00), order, "Test credit")
    end

    it "returns transaction history" do
      get "/api/v1/account/transactions", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(1)
      expect(response.parsed_body.first["operation_type"]).to eq("credit")
      expect(response.parsed_body.first["description"]).to eq("Test credit")
    end

    it "includes balance snapshots" do
      get "/api/v1/account/transactions", as: :json
      tx = response.parsed_body.first
      expect(tx).to include("balance_before", "balance_after")
    end

    it "orders transactions by created_at desc" do
      account.credit!(Money.new(100_00), order, "Second credit")

      get "/api/v1/account/transactions", as: :json
      expect(response.parsed_body.map { |t| t["description"] }).to eq([ "Second credit", "Test credit" ])
    end
  end

  describe "without authentication" do
    before do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({})
    end

    it "returns unauthorized for account" do
      get "/api/v1/account", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized for transactions" do
      get "/api/v1/account/transactions", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
