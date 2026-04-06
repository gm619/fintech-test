# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :user
    sequence(:action) { |n| AuditLog::ACTIONS[n % AuditLog::ACTIONS.size] }
    entity_type { "Order" }
    entity_id { create(:order).id }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0" }
    metadata { {} }
  end
end
