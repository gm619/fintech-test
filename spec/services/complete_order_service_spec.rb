require 'rails_helper'

RSpec.describe CompleteOrderService do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }
  let!(:internal_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0) }

  before { user.account.update!(balance: Money.new(20_000)) }

  it 'completes order via cascade and creates debit transaction' do
    expect { described_class.new(order).call }
      .to change { user.account.reload.balance.cents }.from(20_000).to(5_000)
      .and change { order.reload.status }.from('created').to('successful')
    expect(order.transactions.last.operation_type).to eq('debit')
    expect(order.transactions.last.provider_name).to eq('internal_balance')
  end

  it 'does not give sufficient funds' do
    order.update(amount: Money.new(30_000))
    expect { described_class.new(order).call }.to raise_error(/Cannot complete order.*Insufficient funds/)
    expect(order.reload.status).to eq('created')
  end

  it 'rejects already successful orders' do
    order.update!(status: 'successful')
    expect { described_class.new(order).call }.to raise_error(/Order already successful/)
    expect(order.reload.status).to eq('successful')
  end

  it 'rejects canceled orders' do
    order.update!(status: 'canceled')
    expect { described_class.new(order).call }.to raise_error(/Order already successful/)
    expect(order.reload.status).to eq('canceled')
  end

  it 'rolls back if order completion fails after payment' do
    balance_before = user.account.reload.balance.cents

    allow(order).to receive(:complete!).and_raise(RuntimeError.new("transition failed"))

    expect {
      described_class.new(order).call
    }.to raise_error(/Cannot complete order/)

    expect(user.account.reload.balance.cents).to eq(balance_before)
    expect(order.reload.status).to eq('created')
  end

  it 'succeeds with exact balance (no insufficient funds)' do
    order.update!(amount: Money.new(20_000))

    expect { described_class.new(order).call }
      .to change { user.account.reload.balance.cents }.to(0)

    expect(order.reload.status).to eq('successful')
  end
end
