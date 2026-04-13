# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record.user == user
  end

  def create?
    user.present?
  end

  def complete?
    user.present? && record.user == user && record.created?
  end

  def cancel?
    user.present? && record.user == user && (record.created? || record.successful?)
  end

  def payment_logs?
    user.present? && record.user == user
  end
end
