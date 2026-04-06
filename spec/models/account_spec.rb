require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:transactions) }
  end

  describe 'validations' do
    it { should validate_numericality_of(:balance).is_greater_than_or_equal_to(0) }
  end

  describe '#debit!' do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:order) { create(:order, user: user) }

    before do
      account.update!(balance: 500.00)
    end

    context 'with sufficient funds' do
      it 'decreases balance' do
        expect {
          account.debit!(100.00, order, 'Test debit')
          account.reload
        }.to change(account, :balance).by(-100.00)
      end

      it 'creates a transaction' do
        expect { account.debit!(100.00, order, 'Test debit') }
          .to change(Transaction, :count).by(1)
      end
    end

    context 'with insufficient funds' do
      it 'raises an error' do
        expect { account.debit!(600.00, order) }
          .to raise_error("Insufficient funds")
      end
    end
  end

  describe '#credit!' do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:order) { create(:order, user: user) }

    before do
      account.update!(balance: 500.00)
    end

    it 'increases balance' do
      expect {
        account.credit!(100.00, order, 'Test credit')
        account.reload
      }.to change(account, :balance).by(100.00)
    end

    it 'creates a transaction' do
      expect { account.credit!(100.00, order, 'Test credit') }
        .to change(Transaction, :count).by(1)
    end
  end
end
