require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_one(:account).dependent(:destroy) }
    it { should have_many(:orders).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:user) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'has_secure_password' do
    let(:user) { create(:user, password: 'secret123', password_confirmation: 'secret123') }

    it 'authenticates with correct password' do
      expect(user.authenticate('secret123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      expect(user.authenticate('wrong')).to eq(false)
    end
  end

  describe 'callbacks' do
    describe '#create_account!' do
      let(:user) { create(:user) }

      it 'creates an account after user creation' do
        expect(user.account).to be_present
        expect(user.account.balance).to eq(0)
      end
    end
  end
end
