require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:order) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:operation_type).in_array(%w[debit credit]) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }

    it 'allows only debit and credit operation types' do
      expect(build(:transaction, operation_type: 'debit')).to be_valid
      expect(build(:transaction, operation_type: 'credit')).to be_valid
      expect(build(:transaction, operation_type: 'invalid')).not_to be_valid
    end
  end
end
