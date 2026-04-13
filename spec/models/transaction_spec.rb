require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'associations' do
    it { should belong_to(:account).required(true) }
    it { should belong_to(:order).required(true) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:operation_type).in_array(%w[debit credit]) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }

    it 'allows only debit and credit operation types' do
      expect(build(:transaction, operation_type: 'debit')).to be_valid
      expect(build(:transaction, operation_type: 'credit')).to be_valid
      expect(build(:transaction, operation_type: 'invalid')).not_to be_valid
    end

    it 'rejects zero amount' do
      tx = build(:transaction, amount_cents: 0)
      expect(tx).not_to be_valid
      expect(tx.errors[:amount]).to be_present
    end

    it 'rejects negative amount' do
      tx = build(:transaction, amount_cents: -1)
      expect(tx).not_to be_valid
    end
  end

  describe 'monetize associations' do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:order) { create(:order, user: user) }

    it 'exposes amount as Money object' do
      tx = account.credit!(Money.new(100_00), order, 'Test')
      expect(tx.amount).to be_a(Money)
      expect(tx.amount.cents).to eq(100_00)
    end

    it 'exposes balance_before as Money object' do
      tx = account.credit!(Money.new(100_00), order)
      expect(tx.balance_before).to be_a(Money)
    end

    it 'exposes balance_after as Money object' do
      tx = account.credit!(Money.new(100_00), order)
      expect(tx.balance_after).to be_a(Money)
    end
  end
end
