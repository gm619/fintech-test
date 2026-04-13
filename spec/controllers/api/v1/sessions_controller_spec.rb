# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::SessionsController, type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

  describe "POST /api/v1/session" do
    context "with valid credentials" do
      it "logs in the user" do
        post "/api/v1/session", params: { email: user.email, password: "password123" }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["id"]).to eq(user.id)
      end

      it "creates an audit log for successful login" do
        expect {
          post "/api/v1/session", params: { email: user.email, password: "password123" }, as: :json
        }.to change { AuditLog.where(action: "user_login").count }.by(1)
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized" do
        post "/api/v1/session", params: { email: user.email, password: "wrong" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        post "/api/v1/session", params: { email: user.email, password: "wrong" }, as: :json
        expect(response.parsed_body["error"]).to eq("Invalid credentials")
      end

      it "creates an audit log for failed login" do
        expect {
          post "/api/v1/session", params: { email: user.email, password: "wrong" }, as: :json
        }.to change { AuditLog.where(action: "login_failed").count }.by(1)
      end
    end

    context "with non-existent email" do
      it "returns unauthorized" do
        post "/api/v1/session", params: { email: "nonexistent@example.com", password: "password123" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/session" do
    before do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
    end

    it "logs out the user" do
      delete "/api/v1/session", as: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/session/current" do
    before do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
    end

    it "returns the current user" do
      get "/api/v1/session/current", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["id"]).to eq(user.id)
      expect(response.parsed_body["user"]["email"]).to eq(user.email)
    end
  end

  describe "GET /api/v1/session/current without authentication" do
    it "returns unauthorized" do
      get "/api/v1/session/current", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
