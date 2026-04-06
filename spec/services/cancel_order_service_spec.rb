require 'rails_helper'

RSpec.describe CancelOrderService do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, amount: 100.00, status: 'successful') }

  before do
    user.account.update!(balance: 400.00)
  end

  describe '#call' do
    context 'with successful order' do
      it 'refunds the order amount' do
        expect { described_class.new(order).call }
          .to change { user.account.reload.balance }.by(Money.new(100_00))
      end

      it 'creates a credit transaction' do
        expect { described_class.new(order).call }
          .to change(Transaction, :count).by(1)
      end

      it 'changes order status to canceled' do
        described_class.new(order).call
        expect(order.reload).to be_canceled
      end
    end

    context 'with non-successful order' do
      let(:order) { create(:order, user: user, status: 'created') }

      it 'raises an error' do
        expect { described_class.new(order).call }
          .to raise_error(/Order not successful/)
      end
    end
  end
end
