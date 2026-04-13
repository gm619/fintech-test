# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def show?
    user.present? && record.user == user
  end

  def transactions?
    user.present? && record.user == user
  end
end
