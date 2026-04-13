require 'rails_helper'

RSpec.describe PaymentProvider::Stripe do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:provider) { create(:payment_provider, :stripe) }

  describe '#process_payment' do
    let(:mock_charge) do
      instance_double(
        "Stripe::Charge",
        id: "ch_test123",
        status: "succeeded",
        to_h: { id: "ch_test123", status: "succeeded", amount: 15_000 }
      )
    end

    before do
      allow(Stripe::Charge).to receive(:create).and_return(mock_charge)
      account.update!(balance: Money.new(20_000))
    end

    it 'creates a charge via Stripe API' do
      provider.process_payment(order, account)

      expect(Stripe::Charge).to have_received(:create).with(
        hash_including(
          amount: 15_000,
          currency: "usd",
          description: "Order #{order.id} payment"
        )
      )
    end

    it 'returns success with transaction data' do
      result = provider.process_payment(order, account)

      expect(result[:success]).to be true
      expect(result[:transaction].provider_name).to eq('stripe')
      expect(result[:transaction].external_transaction_id).to eq('ch_test123')
      expect(result[:transaction].provider_status).to eq('succeeded')
    end

    it 'returns provider_inactive when disabled' do
      provider.update!(is_active: false)

      result = provider.process_payment(order, account)

      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:provider_inactive)
    end

    it 'raises error when secret_key not configured' do
      provider.update!(config: {})
      allow(Rails.application.credentials).to receive(:dig).with(:stripe, :secret_key).and_return(nil)

      expect { provider.process_payment(order, account) }
        .to raise_error("Stripe secret_key not configured")
    end
  end

  describe '#refund' do
    let!(:payment_transaction) do
      mock_charge = instance_double("Stripe::Charge", id: "ch_test123", status: "succeeded", to_h: {})
      allow(Stripe::Charge).to receive(:create).and_return(mock_charge)
      account.update!(balance: Money.new(20_000))
      provider.process_payment(order, account)[:transaction]
    end

    let(:mock_refund) do
      instance_double("Stripe::Refund", id: "re_test123", status: "succeeded", to_h: { id: "re_test123" })
    end

    it 'creates a refund on Stripe' do
      allow(Stripe::Refund).to receive(:create).and_return(mock_refund)

      result = provider.refund(payment_transaction)

      expect(Stripe::Refund).to have_received(:create).with(charge: "ch_test123")
      expect(result[:success]).to be true
      expect(result[:transaction].operation_type).to eq('credit')
      expect(result[:transaction].external_transaction_id).to eq('re_test123')
    end
  end

  describe '.verify_webhook_signature' do
    it 'delegates to Stripe::Webhook.construct_event' do
      payload = '{"type": "payment_intent.succeeded"}'
      sig_header = "test_sig"
      secret = "whsec_test"

      mock_event = instance_double("Stripe::Event", type: "payment_intent.succeeded")
      allow(Stripe::Webhook).to receive(:construct_event)
        .with(payload, sig_header, secret)
        .and_return(mock_event)

      event = described_class.verify_webhook_signature(payload, sig_header, secret)
      expect(event).to eq(mock_event)
    end
  end
end
