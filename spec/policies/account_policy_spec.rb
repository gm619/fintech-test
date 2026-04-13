# frozen_string_literal: true

require "rails_helper"
require "pundit/rspec"

RSpec.describe AccountPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { user.account }

  permissions :show? do
    it "allows owners to view their account" do
      expect(subject).to permit(user, account)
    end

    it "denies other users from viewing accounts" do
      expect(subject).not_to permit(other_user, account)
    end

    it "denies nil user" do
      expect(subject).not_to permit(nil, account)
    end
  end

  permissions :transactions? do
    it "allows owners to view their transactions" do
      expect(subject).to permit(user, account)
    end

    it "denies other users from viewing transactions" do
      expect(subject).not_to permit(other_user, account)
    end

    it "denies nil user" do
      expect(subject).not_to permit(nil, account)
    end
  end
end
