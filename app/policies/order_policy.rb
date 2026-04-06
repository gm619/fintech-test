# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    record.user == user
  end

  def create?
    user.present?
  end

  def complete?
    record.user == user && record.created?
  end

  def cancel?
    record.user == user && record.created?
  end

  def payment_logs?
    record.user == user
  end
end
