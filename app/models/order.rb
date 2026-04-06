class Order < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :transactions

  monetize :amount_cents, as: :amount

  validates :amount, numericality: { greater_than: 0, less_than: 1_000_000_000 }
  validates :amount, presence: true

  aasm column: :status do
    state :created, initial: true
    state :successful
    state :canceled

    event :complete do
      transitions from: :created, to: :successful
    end

    event :cancel do
      transitions from: :created, to: :canceled
      transitions from: :successful, to: :canceled
    end
  end
end
