class PaymentProvider < ApplicationRecord
  include Auditable
  self.audit_name = "PaymentProvider"

  self.store_full_sti_class = true

  # Override STI class resolution to handle our naming
  def self.find_sti_class(class_name)
    class_name.constantize
  end

  validates :name, presence: true, uniqueness: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered_by_priority, -> { active.order(:priority) }

  # Returns the configured providers ready for use
  def self.available_providers
    # Ensure subclasses are loaded
    _sti_class_names
    ordered_by_priority.map { |record| record.provider_instance }
  end

  def self._sti_class_names
    PaymentProvider::InternalBalance
    PaymentProvider::Stripe
    PaymentProvider::PayPal
    []
  end

  # Returns a provider instance for this record
  def provider_instance
    self
  end

  # Whether errors from this provider should trigger cascade retry
  def retryable_reason?(reason)
    case reason
    when :insufficient_funds, :provider_error, :card_declined
      true
    when :fraud_suspected, :invalid_request, :provider_inactive
      false
    else
      false
    end
  end

  # Find provider by name and return its instance
  def self.find_by_name!(name)
    find_by!(name: name)
  end

  # Convenience: find the original provider used for a transaction
  def self.for_transaction(transaction)
    return nil unless transaction.provider_name
    find_by(name: transaction.provider_name)
  end

  # Seed default providers (idempotent)
  def self.seed_defaults
    return if exists?(name: "internal_balance")

    create!(name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0, is_active: true)
    create!(name: "stripe", type: "PaymentProvider::Stripe", priority: 10, is_active: false, config: {})
    create!(name: "paypal", type: "PaymentProvider::PayPal", priority: 20, is_active: false, config: {})
  end
end
