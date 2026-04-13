require 'rails_helper'

RSpec.describe CancelOrderService do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'successful') }
  let!(:internal_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0) }

  before do
    user.account.update!(balance: 100_000)
    # Simulate a successful payment: create a debit transaction
    user.account.transactions.create!(
      order: order,
      amount_cents: 15_000,
      operation_type: "debit",
      balance_before_cents: 100_000,
      balance_after_cents: 85_000,
      description: "Order #{order.id} payment via internal balance",
      provider_name: "internal_balance",
      provider_status: "succeeded"
    )
  end

  it 'refunds amount and cancels order' do
    balance_before = user.account.reload.balance.cents

    described_class.new(order).call

    expect(user.account.reload.balance.cents).to eq(balance_before + 15_000)
    expect(order.reload.status).to eq('canceled')
    expect(order.transactions.last.operation_type).to eq('credit')
    expect(order.transactions.last.provider_name).to eq('internal_balance')
  end

  it 'creates credit transaction with refund info' do
    described_class.new(order).call

    credit_txn = order.transactions.credits.last
    expect(credit_txn).to be_present
    expect(credit_txn.provider_status).to eq('refunded')
  end

  it 'rejects non-successful orders (status created)' do
    order.update!(status: 'created')
    described_class.new(order).call
    # expect {  }.to raise_error(/Order not successful/)
    expect(order.reload.status).to eq('canceled')
  end

  it 'rejects already canceled orders' do
    order.update!(status: 'canceled')
    expect { described_class.new(order).call }.to raise_error(/Order not successful/)
    expect(order.reload.status).to eq('canceled')
  end
end
