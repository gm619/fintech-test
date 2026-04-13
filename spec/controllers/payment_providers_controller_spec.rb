require 'rails_helper'

RSpec.describe "Api::V1::PaymentProvidersController", type: :request do
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
  end

  describe 'GET /api/v1/payment_providers' do
    before do
      create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0, is_active: true)
      create(:payment_provider, :stripe, priority: 10, is_active: false)
      create(:payment_provider, :paypal, priority: 20, is_active: true)
    end

    it 'returns only active providers ordered by priority' do
      get "/api/v1/payment_providers", as: :json

      expect(response).to have_http_status(:ok)
      providers = response.parsed_body
      expect(providers.length).to eq(2)
      expect(providers[0]["name"]).to eq("internal_balance")
      expect(providers[1]["name"]).to eq("paypal")
    end

    it 'requires authentication' do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({})
      get "/api/v1/payment_providers", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
