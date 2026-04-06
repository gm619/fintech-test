class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :order

  validates :operation_type, inclusion: { in: %w[debit credit] }
  validates :amount, numericality: { greater_than: 0 }
end
