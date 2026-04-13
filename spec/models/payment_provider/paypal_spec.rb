require 'rails_helper'

RSpec.describe PaymentProvider::PayPal do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:provider) { create(:payment_provider, :paypal) }

  describe '#process_payment' do
    before { account.update!(balance: Money.new(20_000)) }

    it 'returns provider_inactive when disabled' do
      provider.update!(is_active: false)

      result = provider.process_payment(order, account)

      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:provider_inactive)
    end

    it 'returns failure when credentials not configured' do
      provider.update!(config: {})
      provider.reload
      allow(Rails.application.credentials).to receive(:dig)
        .and_return(nil)

      result = provider.process_payment(order, account)

      expect(result[:success]).to be false
      expect(result[:error]).to include("PayPal client_id not configured")
    end
  end
end
