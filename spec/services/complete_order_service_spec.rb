require 'rails_helper'

RSpec.describe CompleteOrderService do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: Money.new(15_000), status: 'created') }

  before do
    user.account.update!(balance: Money.new(20_000))
  end

  it 'списывает деньги и меняет статус' do
    expect { described_class.new(order).call }
      .to change { user.account.reload.balance.cents }.from(20_000).to(5_000)
      .and change { order.reload.status }.from('created').to('successful')
    expect(order.transactions.last.operation_type).to eq('debit')
  end

  it 'не дает списать больше баланса' do
    order.update(amount: Money.new(30_000))
    expect { described_class.new(order).call }.to raise_error(/Insufficient funds/)
    expect(order.reload.status).to eq('created')
  end
end
