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
      account.update!(balance: Money.new(500_00))
    end

    context 'with sufficient funds' do
      it 'decreases balance' do
        expect {
          account.debit!(100_00, order, 'Test debit')
          account.reload
        }.to change(account, :balance).by(Money.new(-100_00))
      end

      it 'creates a transaction' do
        expect { account.debit!(100.00, order, 'Test debit') }
          .to change(Transaction, :count).by(1)
      end

      it 'creates transaction with correct attributes' do
        account.debit!(100_00, order, 'Test debit')
        tx = account.transactions.last
        expect(tx.operation_type).to eq('debit')
        expect(tx.amount.cents).to eq(100_00)
        expect(tx.description).to eq('Test debit')
        expect(tx.order).to eq(order)
      end

      it 'records correct balance snapshots' do
        account.debit!(Money.new(100_00), order)
        tx = account.transactions.last
        expect(tx.balance_before.cents).to eq(500_00)
        expect(tx.balance_after.cents).to eq(400_00)
      end
    end

    context 'with exact balance' do
      it 'succeeds and balance becomes zero' do
        expect {
          account.debit!(500_00, order)
          account.reload
        }.to change(account, :balance).to(Money.new(0))
      end
    end

    context 'with insufficient funds' do
      it 'raises an error' do
        expect { account.debit!(600_00, order) }
          .to raise_error("Insufficient funds")
      end

      it 'does not create a transaction' do
        expect {
          account.debit!(600_00, order)
        }.to raise_error("Insufficient funds")
        expect(account.transactions.count).to eq(0)
      end

      it 'does not change balance' do
        balance_before = account.reload.balance
        expect {
          account.debit!(600_00, order)
        }.to raise_error("Insufficient funds")
        expect(account.reload.balance).to eq(balance_before)
      end
    end

    context 'with zero amount' do
      it 'raises ArgumentError' do
        expect { account.debit!(0, order) }
          .to raise_error(ArgumentError, /Amount must be positive/)
      end
    end

    context 'with negative amount' do
      it 'raises ArgumentError' do
        expect { account.debit!(-100_00, order) }
          .to raise_error(ArgumentError, /Amount must be positive/)
      end
    end
  end

  describe '#credit!' do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:order) { create(:order, user: user) }

    before do
      account.update!(balance: Money.new(500_00))
    end

    it 'increases balance' do
      expect {
        account.credit!(100_00, order, 'Test credit')
        account.reload
      }.to change(account, :balance).by(Money.new(100_00))
    end

    it 'creates a transaction' do
      expect { account.credit!(100.00, order, 'Test credit') }
        .to change(Transaction, :count).by(1)
    end

    it 'creates transaction with correct attributes' do
      account.credit!(100_00, order, 'Test credit')
      tx = account.transactions.last
      expect(tx.operation_type).to eq('credit')
      expect(tx.amount.cents).to eq(100_00)
      expect(tx.description).to eq('Test credit')
      expect(tx.order).to eq(order)
    end

    it 'records correct balance snapshots' do
      account.credit!(Money.new(100_00), order)
      tx = account.transactions.last
      expect(tx.balance_before.cents).to eq(500_00)
      expect(tx.balance_after.cents).to eq(600_00)
    end

    context 'with zero amount' do
      it 'raises ArgumentError' do
        expect { account.credit!(0, order) }
          .to raise_error(ArgumentError, /Amount must be positive/)
      end
    end

    context 'with negative amount' do
      it 'raises ArgumentError' do
        expect { account.credit!(-100_00, order) }
          .to raise_error(ArgumentError, /Amount must be positive/)
      end
    end
  end
end
