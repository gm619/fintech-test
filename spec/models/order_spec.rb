require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:transactions) }
  end

  describe 'validations' do
    it { should validate_numericality_of(:amount).is_greater_than(0) }

    context 'with boundary values' do
      it 'rejects zero amount' do
        order = build(:order, amount_cents: 0)
        expect(order).not_to be_valid
        expect(order.errors[:amount]).to include("must be greater than 0")
      end

      it 'rejects negative amount' do
        order = build(:order, amount_cents: -1)
        expect(order).not_to be_valid
      end

      it 'accepts 999_999_999' do
        order = build(:order, amount_cents: 99_999_999_900) # $999,999,999.00
        expect(order).to be_valid
      end

      it 'rejects 1_000_000_000 and above' do
        order = build(:order, amount_cents: 100_000_000_000) # $1,000,000,000.00
        expect(order).not_to be_valid
        expect(order.errors[:amount]).to include("must be less than 1000000000")
      end
    end
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

      it 'cannot transition from canceled to successful' do
        order.cancel!
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

      it 'cannot cancel an already canceled order' do
        order.cancel!
        expect { order.cancel! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end
end
