class CompleteOrderService
  def initialize(order)
    @order = order
    @user = order.user
  end

  def call
    raise "Order already successful" unless @order.created?

    Account.transaction do
      account = @user.account.lock!
      raise "Insufficient funds" if account.balance < @order.amount

      account.debit!(@order.amount, @order, "Order #{@order.id} payment")
      @order.complete!
    end
    true
  rescue AASM::InvalidTransition, RuntimeError => e
    raise "Cannot complete order: #{e.message}"
  end
end
