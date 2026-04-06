# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true

  # Действия для аудита
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
