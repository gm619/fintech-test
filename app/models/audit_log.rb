# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true

  # Polymorphic entity access
  def entity
    return nil unless entity_type.present? && entity_id.present?
    entity_type.constantize.find_by(id: entity_id)
  end

  # Действия для аудита (автогенерируемые + ручные)
  # Авто: {entity}_created, {entity}_updated, {entity}_deleted
  ACTIONS = %w[
    user_login
    user_logout
    order_created
    order_completed
    order_canceled
    account_debited
    account_credited
    payment_attempt
    payment_failed
    user_created
    user_updated
    user_deleted
    order_updated
    order_deleted
    account_created
    account_updated
    account_deleted
    transaction_created
    transaction_updated
    transaction_deleted
  ].freeze

  validates :action, inclusion: { in: ACTIONS }

  # Вспомогательные методы для логирования
  class << self
    def log!(user:, action:, entity: nil, metadata: {}, request: nil)
      create!(
        user: user,
        action: action,
        entity_type: entity&.class&.name,
        entity_id: entity&.id,
        metadata: metadata,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent
      )
    end
  end
end
