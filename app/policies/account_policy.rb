# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def show?
    record.user == user
  end

  def transactions?
    record.user == user
  end
end
