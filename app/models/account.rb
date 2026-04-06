class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions

  monetize :balance_cents, as: :balance, disable_validation: false

  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  # NOTE: Блокировка должна происходить на уровне сервиса, не здесь
  # Этот метод вызывается внутри транзакции с уже установленной блокировкой

  def debit!(amount, order, description = nil)
    amount = Money.new(amount) if amount.is_a?(Numeric)

    raise "Insufficient funds" if balance < amount

    old_balance = balance
    update!(balance: balance - amount)
    transactions.create!(
      order: order,
      amount_cents: amount.cents,
      operation_type: "debit",
      balance_before_cents: old_balance.cents,
      balance_after_cents: balance.cents,
      description: description
    )
  end

  def credit!(amount, order, description = nil)
    amount = Money.new(amount) if amount.is_a?(Numeric)

    old_balance = balance
    update!(balance: balance + amount)
    transactions.create!(
      order: order,
      amount_cents: amount.cents,
      operation_type: "credit",
      balance_before_cents: old_balance.cents,
      balance_after_cents: balance.cents,
      description: description
    )
  end
end
