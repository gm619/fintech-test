# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auditable do
  let(:user) { create(:user) }

  before do
    Thread.current[:audit_user] = nil
    Thread.current[:audit_request] = nil
  end

  describe "User model" do
    it "logs user creation" do
      Thread.current[:audit_user] = nil
      expect {
        create(:user, email: "new_#{SecureRandom.hex(6)}@example.com")
      }.to change(AuditLog, :count).by(2) # user + account

      audit = AuditLog.where(entity_type: "User").last
      expect(audit.action).to eq("user_created")
      expect(audit.user).to be_nil
    end

    it "logs user creation with audit context" do
      admin_user = create(:user, email: "admin_#{SecureRandom.hex(6)}@example.com")
      Thread.current[:audit_user] = admin_user

      expect {
        create(:user, email: "new2_#{SecureRandom.hex(6)}@example.com")
      }.to change(AuditLog, :count).by(2) # user + account

      audit = AuditLog.where(entity_type: "User").last
      expect(audit.action).to eq("user_created")
      expect(audit.user).to eq(admin_user)
    end

    it "logs user update" do
      user.update!(email: "updated_#{user.email}")

      audit = AuditLog.last
      expect(audit.action).to eq("user_updated")
      expect(audit.metadata).to include("email")
    end

    it "logs user deletion" do
      user_id = user.id
      user.destroy

      audit = AuditLog.last
      expect(audit.action).to eq("user_deleted")
      expect(audit.entity_id).to eq(user_id)
    end

    it "excludes password_digest from audit" do
      user.update!(password: "newpassword123", password_confirmation: "newpassword123")

      audit = AuditLog.last
      expect(audit.metadata.keys).not_to include("password_digest")
    end
  end

  describe "Order model" do
    let(:order) { create(:order, user: user) }

    before do
      Thread.current[:audit_user] = user
    end

    it "logs order creation" do
      expect {
        create(:order, user: user)
      }.to change(AuditLog, :count).by(1)

      audit = AuditLog.where(entity_type: "Order").last
      expect(audit.action).to eq("order_created")
      expect(audit.entity).to be_a(Order)
    end

    it "logs order update (status change)" do
      order.complete!

      audit = AuditLog.last
      expect(audit.action).to eq("order_updated")
      expect(audit.metadata).to include("status")
    end

    it "logs order cancellation" do
      order.cancel!

      audit = AuditLog.last
      expect(audit.action).to eq("order_updated")
      expect(audit.metadata["status"]["to"]).to eq("canceled")
    end
  end

  describe "Account model" do
    let(:account) { user.account }

    before do
      Thread.current[:audit_user] = user
    end

    it "logs account creation" do
      # Account is created via User after_create callback, which happens in the same transaction
      # The audit user context needs to be set before user creation
      Thread.current[:audit_user] = user
      new_user = create(:user, email: "acc_#{SecureRandom.hex(6)}@example.com")

      audit = AuditLog.where(entity_type: "Account").last
      expect(audit.action).to eq("account_created")
      expect(audit.entity).to eq(new_user.account)
    end

    it "logs balance changes" do
      account.update!(balance_cents: 500_00)

      audit = AuditLog.where(entity_type: "Account").last
      expect(audit.action).to eq("account_updated")
      expect(audit.metadata).to include("balance_cents")
    end
  end

  describe "Transaction model" do
    let(:account) { user.account }
    let(:order) { create(:order, user: user) }

    before do
      Thread.current[:audit_user] = user
    end

    it "logs transaction creation" do
      expect {
        account.credit!(Money.new(100_00), order, "Test credit")
      }.to change(AuditLog, :count).by(3) # transaction + account update + order update

      audit = AuditLog.where(entity_type: "Transaction").last
      expect(audit.action).to eq("transaction_created")
      expect(audit.entity).to be_a(Transaction)
    end
  end

  describe "without_auditing" do
    it "skips audit logging when called" do
      expect {
        User.without_auditing do
          create(:user, email: "silent_#{SecureRandom.hex(6)}@example.com")
        end
      }.not_to change(AuditLog, :count)
    end

    it "restores audit setting after block" do
      User.without_auditing do
        create(:user, email: "silent2_#{SecureRandom.hex(6)}@example.com")
      end

      expect {
        create(:user, email: "audit_#{SecureRandom.hex(6)}@example.com")
      }.to change(AuditLog, :count).by(2) # user + account
    end
  end

  describe "audit context" do
    it "associates audit log with current user from thread" do
      # Set audit context before creating the user
      Thread.current[:audit_user] = user

      # Create a different entity - the audit should be associated with the context user
      other_user = create(:user, email: "context_#{SecureRandom.hex(6)}@example.com")

      # The last audit log for the other_user creation should have the context user
      audit = AuditLog.where(entity_type: "User").last
      expect(audit.user).to eq(user)
    end

    it "handles missing user gracefully" do
      Thread.current[:audit_user] = nil

      expect {
        create(:user, email: "noctx_#{SecureRandom.hex(6)}@example.com")
      }.not_to raise_error
    end
  end
end
