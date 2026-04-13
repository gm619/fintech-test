# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyKey, type: :model do
  describe "validations" do
    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:response_body) }
    it { should validate_presence_of(:status) }

    describe "uniqueness of key" do
      before { create(:idempotency_key, key: "unique-key", status: 200, response_body: "{}") }

      it { is_expected.not_to allow_value("unique-key").for(:key) }
    end
  end

  describe ".cleanup" do
    it "removes keys older than 24 hours" do
      old_key = create(:idempotency_key, key: "old-key", status: 200, response_body: "{}", created_at: 25.hours.ago)
      recent_key = create(:idempotency_key, key: "recent-key", status: 200, response_body: "{}")

      described_class.cleanup

      expect(IdempotencyKey.exists?(old_key.id)).to be false
      expect(IdempotencyKey.exists?(recent_key.id)).to be true
    end

    it "does not remove keys created recently" do
      boundary_key = create(:idempotency_key, key: "boundary-key", status: 200, response_body: "{}")

      described_class.cleanup

      expect(IdempotencyKey.exists?(boundary_key.id)).to be true
    end
  end
end
