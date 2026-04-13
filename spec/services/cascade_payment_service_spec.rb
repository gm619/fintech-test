require 'rails_helper'

RSpec.describe CascadePaymentService do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }

  describe '#call' do
    context 'with internal balance provider having sufficient funds' do
      let!(:internal_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0) }

      before { account.update!(balance: Money.new(20_000)) }

      it 'succeeds with internal balance' do
        result = described_class.new(order, account).call

        expect(result[:success]).to be true
        expect(result[:transaction].provider_name).to eq('internal_balance')
      end

      it 'deducts the correct amount' do
        expect { described_class.new(order, account).call }
          .to change { account.reload.balance.cents }.from(20_000).to(5_000)
      end
    end

    context 'with multiple providers cascading' do
      let!(:internal_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0, is_active: false) }
      let!(:stripe_provider) { create(:payment_provider, :stripe, priority: 10) }

      before { account.update!(balance: Money.new(20_000)) }

      it 'tries providers in priority order' do
        mock_charge = instance_double("Stripe::Charge", id: "ch_test123", status: "succeeded", to_h: {})
        allow(Stripe::Charge).to receive(:create).and_return(mock_charge)

        result = described_class.new(order, account).call

        expect(result[:success]).to be true
        expect(result[:transaction].provider_name).to eq('stripe')
      end
    end

    context 'when all providers fail with retryable errors' do
      let!(:internal_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0, is_active: false) }
      let!(:stripe_provider) { create(:payment_provider, :stripe, priority: 10) }

      before { account.update!(balance: Money.new(20_000)) }

      it 'returns failure with all attempts logged' do
        allow(Stripe::Charge).to receive(:create).and_raise(
          Stripe::AuthenticationError.new("Invalid API Key")
        )

        result = described_class.new(order, account).call

        expect(result[:success]).to be false
        expect(result[:attempts].length).to eq(1)
        expect(result[:attempts].first[:provider]).to eq('stripe')
        expect(result[:error]).to include("All payment providers failed")
      end
    end

    context 'with no active providers' do
      it 'returns failure result' do
        result = described_class.new(order, account).call

        expect(result[:success]).to be false
        expect(result[:error]).to include("No payment providers configured")
      end
    end
  end
end
