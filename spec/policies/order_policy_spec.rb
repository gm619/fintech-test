# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe OrderPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:order) { create(:order, user: user) }

  permissions :index? do
    it "allows authenticated users" do
      expect(subject).to permit(user)
    end

    it "denies unauthenticated users" do
      expect(subject).not_to permit(nil, Order)
    end
  end

  permissions :show? do
    it "allows owners to view their orders" do
      expect(subject).to permit(user, order)
    end

    it "denies other users from viewing orders" do
      expect(subject).not_to permit(other_user, order)
    end
  end

  permissions :create? do
    it "allows authenticated users" do
      expect(subject).to permit(user)
    end

    it "denies unauthenticated users" do
      expect(subject).not_to permit(nil, Order)
    end
  end

  permissions :complete? do
    let(:created_order) { create(:order, user: user, status: "created") }
    let(:successful_order) { create(:order, user: user, status: "successful") }

    it "allows owners to complete created orders" do
      expect(subject).to permit(user, created_order)
    end

    it "denies completing already successful orders" do
      expect(subject).not_to permit(user, successful_order)
    end

    it "denies other users from completing orders" do
      expect(subject).not_to permit(other_user, created_order)
    end
  end

  permissions :cancel? do
    let(:created_order) { create(:order, user: user, status: "created") }
    let(:successful_order) { create(:order, user: user, status: "successful") }
    let(:canceled_order) { create(:order, user: user, status: "canceled") }

    it "allows owners to cancel created orders" do
      expect(subject).to permit(user, created_order)
    end

    it "allows owners to cancel successful orders" do
      expect(subject).to permit(user, successful_order)
    end

    it "denies canceling already canceled orders" do
      expect(subject).not_to permit(user, canceled_order)
    end

    it "denies other users from canceling orders" do
      expect(subject).not_to permit(other_user, created_order)
    end

    it "denies nil user from canceling orders" do
      expect(subject).not_to permit(nil, created_order)
    end
  end

  permissions :payment_logs? do
    it "allows owners to view payment logs" do
      expect(subject).to permit(user, order)
    end

    it "denies other users from viewing payment logs" do
      expect(subject).not_to permit(other_user, order)
    end
  end

  permissions :complete? do
    let(:canceled_order) { create(:order, user: user, status: "canceled") }

    it "denies completing canceled orders" do
      expect(subject).not_to permit(user, canceled_order)
    end
  end
end
