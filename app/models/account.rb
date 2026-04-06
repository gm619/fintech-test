class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions

  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  # NOTE: Блокировка должна происходить на уровне сервиса, не здесь
  # Этот метод вызывается внутри транзакции с уже установленной блокировкой

  def debit!(amount, order, description = nil)
    raise "Insufficient funds" if balance < amount

    old_balance = balance
    update!(balance: balance - amount)
    transactions.create!(
      order: order,
      amount: amount,
      operation_type: "debit",
      balance_before: old_balance,
      balance_after: balance,
      description: description
    )
  end

  def credit!(amount, order, description = nil)
    old_balance = balance
    update!(balance: balance + amount)
    transactions.create!(
      order: order,
      amount: amount,
      operation_type: "credit",
      balance_before: old_balance,
      balance_after: balance,
      description: description
    )
  end
end
