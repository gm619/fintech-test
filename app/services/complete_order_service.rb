class CompleteOrderService
  def initialize(order)
    @order = order
    @user = order.user
  end

  def call
    raise "Order already successful" unless @order.created?

    Account.transaction do
      @user.account.lock!

      result = CascadePaymentService.new(@order, @user.account).call

      unless result[:success]
        audit_payment_failed(result)
        raise "Cannot complete order: #{result[:error]}"
      end

      # Payment succeeded — now complete the order
      @order.complete!
      audit_order_completed(result)
    end
    true
  rescue AASM::InvalidTransition, StandardError => e
    raise "Cannot complete order: #{e.message}"
  end

  private

  def audit_payment_failed(result)
    AuditLog.log!(
      user: @user,
      action: "payment_failed",
      entity: @order,
      metadata: { error: result[:error], attempts: result[:attempts] },
      request: RequestStore.store[:audit_request]
    )
  rescue => e
    Rails.logger.error("Failed to write audit log: #{e.message}")
  end

  def audit_order_completed(result)
    AuditLog.log!(
      user: @user,
      action: "order_completed",
      entity: @order,
      metadata: {
        provider: result[:transaction].provider_name,
        external_transaction_id: result[:transaction].external_transaction_id
      },
      request: RequestStore.store[:audit_request]
    )
  rescue => e
    Rails.logger.error("Failed to write audit log: #{e.message}")
  end
end
