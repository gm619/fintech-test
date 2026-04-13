# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheckController, type: :request do
  describe "GET /up" do
    it "returns 200 when database is available" do
      get "/up", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("ok")
    end
  end
end
