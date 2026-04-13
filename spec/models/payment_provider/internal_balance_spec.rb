require 'rails_helper'

RSpec.describe PaymentProvider::InternalBalance do
  # Force subclass loading
  before { PaymentProvider::InternalBalance }

  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0) }

  describe '#process_payment' do
    before { account.update!(balance: Money.new(20_000)) }

    it 'creates a debit transaction with provider info' do
      result = provider.process_payment(order, account)

      expect(result[:success]).to be true
      expect(result[:transaction]).to be_present
      expect(result[:transaction].operation_type).to eq('debit')
      expect(result[:transaction].provider_name).to eq('internal_balance')
      expect(result[:transaction].amount_cents).to eq(15_000)
      expect(result[:error]).to be_nil
    end

    it 'deducts from account balance' do
      expect { provider.process_payment(order, account) }
        .to change { account.reload.balance.cents }.from(20_000).to(5_000)
    end

    it 'fails with insufficient funds' do
      order.update!(amount: Money.new(30_000))

      result = provider.process_payment(order, account)

      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:insufficient_funds)
      expect(result[:error]).to include("Insufficient funds")
    end

    it 'returns provider_inactive when disabled' do
      provider.update!(is_active: false)

      result = provider.process_payment(order, account)

      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:provider_inactive)
    end
  end

  describe '#refund' do
    let!(:payment_transaction) do
      account.update!(balance: Money.new(20_000))
      provider.process_payment(order, account)[:transaction]
    end

    it 'creates a credit transaction' do
      result = provider.refund(payment_transaction)

      expect(result[:success]).to be true
      expect(result[:transaction].operation_type).to eq('credit')
      expect(result[:transaction].provider_name).to eq('internal_balance')
      expect(result[:transaction].provider_status).to eq('refunded')
    end

    it 'increases account balance' do
      balance_before = account.reload.balance.cents

      provider.refund(payment_transaction)

      expect(account.reload.balance.cents).to eq(balance_before + 15_000)
    end
  end

  describe '#status' do
    it 'returns not_applicable' do
      result = provider.status("external_123")
      expect(result[:status]).to eq("not_applicable")
    end
  end
end
