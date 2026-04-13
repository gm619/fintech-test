require 'rails_helper'

RSpec.describe "Webhooks::PayPalController", type: :request do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:transaction) do
    create(:transaction,
      account: user.account,
      order: order,
      amount_cents: 15_000,
      operation_type: "debit",
      provider_name: "paypal",
      external_transaction_id: "PAYPAL-CAPTURE-123",
      provider_status: "PENDING"
    )
  end

  describe 'POST /webhooks/paypal' do
    it 'handles PAYMENT.CAPTURE.COMPLETED' do
      payload = {
        event_type: "PAYMENT.CAPTURE.COMPLETED",
        resource: {
          id: "PAYPAL-CAPTURE-123",
          status: "COMPLETED",
          amount: { value: "150.00", currency_code: "USD" }
        }
      }.to_json

      post "/webhooks/paypal", params: payload, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(transaction.reload.provider_status).to eq("COMPLETED")
    end

    it 'handles PAYMENT.CAPTURE.DENIED' do
      payload = {
        event_type: "PAYMENT.CAPTURE.DENIED",
        resource: {
          id: "PAYPAL-CAPTURE-123",
          status: "DENIED"
        }
      }.to_json

      post "/webhooks/paypal", params: payload, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(transaction.reload.provider_status).to eq("DENIED")
    end

    it 'handles invalid JSON' do
      post "/webhooks/paypal", params: "not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
    end

    it 'handles unknown event types' do
      payload = {
        event_type: "UNKNOWN.EVENT",
        resource: {}
      }.to_json

      post "/webhooks/paypal", params: payload, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end
end
