class Transaction < ApplicationRecord
  include Auditable
  self.audit_name = "Transaction"

  belongs_to :account
  belongs_to :order

  monetize :amount_cents, as: :amount
  monetize :balance_before_cents, as: :balance_before
  monetize :balance_after_cents, as: :balance_after

  ALLOWED_PROVIDERS = %w[internal_balance stripe paypal].freeze

  validates :operation_type, inclusion: { in: %w[debit credit] }
  validates :amount, numericality: { greater_than: 0 }
  validates :provider_name, inclusion: { in: ALLOWED_PROVIDERS }, allow_nil: true

  # Scope: only debit transactions
  scope :debits, -> { where(operation_type: "debit") }
  # Scope: only credit transactions
  scope :credits, -> { where(operation_type: "credit") }
  # Scope: external (non-internal-balance) transactions
  scope :external, -> { where.not(provider_name: "internal_balance") }
end
