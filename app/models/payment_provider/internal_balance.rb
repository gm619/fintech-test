class PaymentProvider::InternalBalance < PaymentProvider
  # Process payment using the user's internal account balance.
  # Mirrors the original Account#debit! behavior.
  def process_payment(order, account)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    amount = order.amount

    account.with_lock do
      raise "Insufficient funds" if account.balance < amount

      old_balance = account.balance
      account.update!(balance: account.balance - amount)

      transaction = account.transactions.create!(
        order: order,
        amount_cents: amount.cents,
        operation_type: "debit",
        balance_before_cents: old_balance.cents,
        balance_after_cents: account.balance.cents,
        description: "Order #{order.id} payment via internal balance",
        provider_name: name,
        external_transaction_id: nil,
        provider_status: "succeeded",
        provider_response: {}
      )

      return { success: true, transaction: transaction, error: nil, reason: nil }
    end
  rescue ActiveRecord::RecordInvalid => e
    { success: false, transaction: nil, error: e.message, reason: :provider_error }
  rescue RuntimeError => e
    fail_result(e.message, :insufficient_funds)
  end

  # Refund by crediting the user's internal balance.
  def refund(original_transaction)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    account = original_transaction.account
    amount = original_transaction.amount

    old_balance = account.balance
    account.update!(balance: account.balance + amount)

    refund_transaction = account.transactions.create!(
      order: original_transaction.order,
      amount_cents: amount.cents,
      operation_type: "credit",
      balance_before_cents: old_balance.cents,
      balance_after_cents: account.balance.cents,
      description: "Refund for order #{original_transaction.order_id} via internal balance",
      provider_name: name,
      external_transaction_id: original_transaction.external_transaction_id,
      provider_status: "refunded",
      provider_response: { original_transaction_id: original_transaction.id }
    )

    { success: true, transaction: refund_transaction, error: nil }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, transaction: nil, error: e.message }
  end

  # Internal balance transactions are synchronous — status is whatever was recorded
  def status(external_transaction_id)
    { status: "not_applicable", details: { message: "Internal balance has no external status" } }
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

  private

  def fail_result(error, reason)
    { success: false, transaction: nil, error: error, reason: reason }
  end
end
