require 'rails_helper'
require 'ostruct'

RSpec.describe "Webhooks::StripeController", type: :request do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:transaction) do
    create(:transaction,
      account: user.account,
      order: order,
      amount_cents: 15_000,
      operation_type: "debit",
      provider_name: "stripe",
      external_transaction_id: "ch_test123",
      provider_status: "pending"
    )
  end

  describe 'POST /webhooks/stripe' do
    let(:webhook_secret) { "whsec_test123" }

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:stripe, :webhook_secret)
        .and_return(webhook_secret)
    end

    it 'handles payment_intent.succeeded' do
      payload = {
        type: "payment_intent.succeeded",
        data: {
          object: {
            id: "pi_test123",
            status: "succeeded",
            latest_charge: "ch_test123"
          }
        }
      }.to_json

      sig_header = "test_signature"
      mock_payment_intent = OpenStruct.new(id: "pi_test123", status: "succeeded", latest_charge: "ch_test123", amount: 15_000, to_h: {})
      mock_data = OpenStruct.new(object: mock_payment_intent)
      mock_event = instance_double(Stripe::Event, type: "payment_intent.succeeded", data: mock_data)
      allow(PaymentProvider::Stripe).to receive(:verify_webhook_signature)
        .with(payload, sig_header, webhook_secret)
        .and_return(mock_event)

      post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => sig_header, "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(transaction.reload.provider_status).to eq("succeeded")
    end

    it 'handles invalid signatures' do
      payload = '{"type": "payment_intent.succeeded"}'

      allow(PaymentProvider::Stripe).to receive(:verify_webhook_signature)
        .and_raise("Invalid signature")

      post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => "bad_sig", "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["status"]).to eq("error")
    end

    it 'handles unhandled event types gracefully' do
      payload = {
        type: "customer.created",
        data: { object: { id: "cus_test" } }
      }.to_json

      mock_event = instance_double(Stripe::Event, type: "customer.created")
      allow(PaymentProvider::Stripe).to receive(:verify_webhook_signature).and_return(mock_event)

      post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => "sig", "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end
end
