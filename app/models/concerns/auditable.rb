# frozen_string_literal: true

module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_creation, if: -> { should_audit? }
    after_update :log_update, if: -> { should_audit? }
    after_destroy :log_deletion, if: -> { should_audit? }
  end

  class_methods do
    def audit_config
      @audit_config ||= { enabled: true, excluded: %w[updated_at], name: nil }
    end

    def audit_name
      audit_config[:name]
    end

    def audit_name=(value)
      audit_config[:name] = value
    end

    def audit_excluded_attributes
      audit_config[:excluded]
    end

    def audit_excluded_attributes=(value)
      audit_config[:excluded] = value
    end

    def audit_enabled?
      audit_config[:enabled]
    end

    def audit_enabled=(value)
      audit_config[:enabled] = value
    end

    def without_auditing
      RequestStore.store[:auditing_disabled] = true
      yield
    ensure
      RequestStore.store[:auditing_disabled] = false
    end

    def auditing_disabled?
      RequestStore.store[:auditing_disabled] == true
    end
  end

  private

  def should_audit?
    return false unless self.class.audit_enabled?
    return false if self.class.auditing_disabled?
    true
  end

  def audit_entity_name
    self.class.audit_name || self.class.name
  end

  def log_creation
    log_action!("created", metadata: attributes_for_audit)
  end

  def log_update
    return if previous_changes.empty?
    return if only_excluded_attributes_changed?

    log_action!("updated", metadata: changed_attributes_for_audit)
  end

  def log_deletion
    log_action!("deleted", metadata: attributes_for_audit)
  end

  def log_action!(action_suffix, metadata:)
    AuditLog.log!(
      user: current_user_for_audit,
      action: "#{audit_entity_name.underscore}_#{action_suffix}",
      entity: self,
      metadata: metadata,
      request: current_request_for_audit
    )
  rescue StandardError => e
    # Не должны блокировать основную операцию из-за ошибки аудита
    Rails.logger.error("[Auditable] Failed to log audit: #{e.message}")
  end

  def current_user_for_audit
    RequestStore.store[:audit_user]
  end

  def current_request_for_audit
    RequestStore.store[:audit_request]
  end

  def audit_excluded_attrs
    self.class.audit_excluded_attributes
  end

  def attributes_for_audit
    attributes
      .except("id", *audit_excluded_attrs)
      .transform_values { |v| serialize_value(v) }
  end

  def changed_attributes_for_audit
    previous_changes
      .except(*audit_excluded_attrs)
      .transform_values { |(old, new)| { from: serialize_value(old), to: serialize_value(new) } }
  end

  def only_excluded_attributes_changed?
    previous_changes.keys.all? { |k| audit_excluded_attrs.include?(k) }
  end

  def serialize_value(value)
    case value
    when BigDecimal then value.to_s
    when Time, DateTime then value.iso8601
    when ActiveRecord::Relation then value.ids
    when ApplicationRecord then { type: value.class.name, id: value.id }
    else value
    end
  end
end
