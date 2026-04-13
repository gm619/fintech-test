class CancelOrderService
  def initialize(order)
    @order = order
    @user = order.user
  end

  def call
    raise "Order not successful" unless @order.created? || @order.successful?

    # Find the original payment transaction for this order (the successful debit)
    payment_transaction = @order.transactions.debits.find_by(provider_name: "internal_balance") ||
                          @order.transactions.debits.first

    unless payment_transaction
      raise "Cannot cancel order: no payment transaction found"
    end

    # Refund through the original provider
    provider = PaymentProvider.for_transaction(payment_transaction)

    unless provider
      # Fallback: if no provider found, default to internal balance
      provider = PaymentProvider.find_by_name!("internal_balance")
    end

    refund_result = provider.refund(payment_transaction)

    unless refund_result[:success]
      raise "Cannot cancel order: refund failed — #{refund_result[:error]}"
    end

    @order.cancel!

    audit_order_canceled
    true
  rescue AASM::InvalidTransition, RuntimeError => e
    raise "Cannot cancel order: #{e.message}"
  end

  private

  def audit_order_canceled
    AuditLog.log!(
      user: @user,
      action: "order_canceled",
      entity: @order,
      metadata: {},
      request: RequestStore.store[:audit_request]
    )
  rescue => e
    Rails.logger.error("Failed to write audit log: #{e.message}")
  end
end
