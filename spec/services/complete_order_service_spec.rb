require 'rails_helper'

RSpec.describe CompleteOrderService do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: 150.00, status: 'created') }

  before do
    user.account.update!(balance: 200.00)
  end

  it 'списывает деньги и меняет статус' do
    expect { described_class.new(order).call }
      .to change { user.account.reload.balance }.from(200.00).to(50.00)
      .and change { order.reload.status }.from('created').to('successful')
    expect(order.transactions.last.operation_type).to eq('debit')
  end

  it 'не дает списать больше баланса' do
    order.update(amount: 300.00)
    expect { described_class.new(order).call }.to raise_error(/Insufficient funds/)
    expect(order.reload.status).to eq('created')
  end
end
