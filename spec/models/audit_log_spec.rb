# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  describe "associations" do
    it { should belong_to(:user).optional }
  end

  describe "validations" do
    it { should validate_presence_of(:action) }

    it "rejects actions not in ACTIONS list" do
      log = described_class.new(action: "invalid_action")
      expect(log).not_to be_valid
      expect(log.errors[:action]).to be_present
    end
  end

  describe "#entity" do
    let(:user) { create(:user) }
    let(:order) { create(:order, user: user) }

    it "returns the correct entity" do
      log = AuditLog.create!(action: "order_created", entity_type: "Order", entity_id: order.id)
      expect(log.entity).to eq(order)
    end

    it "returns nil when entity_type is nil" do
      log = AuditLog.create!(action: "user_login", entity_type: nil, entity_id: nil)
      expect(log.entity).to be_nil
    end

    it "returns nil when entity_id is nil" do
      log = AuditLog.create!(action: "user_login", entity_type: "User", entity_id: nil)
      expect(log.entity).to be_nil
    end

    it "returns nil when entity no longer exists" do
      log = AuditLog.create!(action: "order_created", entity_type: "Order", entity_id: 999_999)
      expect(log.entity).to be_nil
    end
  end

  describe ".log!" do
    let(:user) { create(:user) }
    let(:order) { create(:order, user: user) }

    it "creates a log with all fields" do
      log = AuditLog.log!(
        user: user,
        action: "order_created",
        entity: order,
        metadata: { amount: 100 },
        request: double(remote_ip: "1.2.3.4", user_agent: "TestAgent")
      )

      expect(log.user).to eq(user)
      expect(log.action).to eq("order_created")
      expect(log.entity_type).to eq("Order")
      expect(log.entity_id).to eq(order.id)
      expect(log.metadata).to include("amount" => 100)
      expect(log.ip_address).to eq("1.2.3.4")
      expect(log.user_agent).to eq("TestAgent")
    end

    it "handles nil user" do
      log = AuditLog.log!(user: nil, action: "user_login")
      expect(log.user).to be_nil
    end

    it "handles nil entity" do
      log = AuditLog.log!(user: user, action: "user_login", entity: nil)
      expect(log.entity_type).to be_nil
      expect(log.entity_id).to be_nil
    end

    it "handles nil request" do
      log = AuditLog.log!(user: user, action: "user_login", request: nil)
      expect(log.ip_address).to be_nil
      expect(log.user_agent).to be_nil
    end
  end
end
