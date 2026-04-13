require 'rails_helper'

RSpec.describe PaymentProvider, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:priority).is_greater_than_or_equal_to(0).only_integer }
  end

  describe 'scopes' do
    let!(:active_provider) { create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0, is_active: true) }
    let!(:inactive_provider) { create(:payment_provider, name: "stripe", type: "PaymentProvider::Stripe", priority: 10, is_active: false) }

    describe '.active' do
      it 'returns only active providers' do
        expect(described_class.active).to include(active_provider)
        expect(described_class.active).not_to include(inactive_provider)
      end
    end

    describe '.ordered_by_priority' do
      it 'orders by priority ascending' do
        expect(described_class.ordered_by_priority.to_a.map(&:priority)).to eq([ 0 ])
      end
    end
  end

  describe '.available_providers' do
    it 'returns instantiated provider objects' do
      provider_record = create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0)
      providers = described_class.available_providers

      expect(providers.first).to be_a(PaymentProvider::InternalBalance)
      expect(providers.first.name).to eq("internal_balance")
    end
  end

  describe '.seed_defaults' do
    it 'creates 3 providers idempotently' do
      expect { described_class.seed_defaults }.to change { described_class.count }.by(3)
      expect { described_class.seed_defaults }.not_to change { described_class.count }

      expect(described_class.find_by(name: "internal_balance")).to be_present
      expect(described_class.find_by(name: "stripe")).to be_present
      expect(described_class.find_by(name: "paypal")).to be_present
    end
  end

  describe '#provider_instance' do
    it 'returns self for InternalBalance' do
      record = create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance")
      expect(record.provider_instance).to eq(record)
      expect(record.provider_instance).to be_a(PaymentProvider::InternalBalance)
    end

    it 'returns self for Stripe' do
      record = create(:payment_provider, :stripe)
      expect(record.provider_instance).to eq(record)
      expect(record.provider_instance).to be_a(PaymentProvider::Stripe)
    end

    it 'returns self for PayPal' do
      record = create(:payment_provider, :paypal)
      expect(record.provider_instance).to eq(record)
      expect(record.provider_instance).to be_a(PaymentProvider::PayPal)
    end
  end
end
