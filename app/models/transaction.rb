class Transaction < ApplicationRecord
  include Auditable
  self.audit_name = "Transaction"

  belongs_to :account
  belongs_to :order

  monetize :amount_cents, as: :amount
  monetize :balance_before_cents, as: :balance_before
  monetize :balance_after_cents, as: :balance_after

  validates :operation_type, inclusion: { in: %w[debit credit] }
  validates :amount, numericality: { greater_than: 0 }
end
