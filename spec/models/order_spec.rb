require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:transactions) }
  end

  describe 'validations' do
    it { should validate_numericality_of(:amount).is_greater_than(0) }
  end

  describe 'AASM states' do
    let(:order) { create(:order) }

    it 'starts in created state' do
      expect(order).to be_created
    end

    describe '#complete!' do
      it 'transitions from created to successful' do
        expect { order.complete! }.to change(order, :status).to('successful')
      end

      it 'cannot transition from successful to successful' do
        order.complete!
        expect { order.complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe '#cancel!' do
      it 'transitions from created to canceled' do
        expect { order.cancel! }.to change(order, :status).to('canceled')
      end

      it 'transitions from successful to canceled' do
        order.complete!
        expect { order.cancel! }.to change(order, :status).to('canceled')
      end
    end
  end
end
