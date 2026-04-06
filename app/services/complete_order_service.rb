class CompleteOrderService
  def initialize(order)
    @order = order
    @user = order.user
  end

  def call
    raise "Order already successful" unless @order.created?

    Account.transaction do
      account = @user.account
      account.debit!(@order.amount, @order, "Order #{@order.id} payment")
      @order.complete!
    end
    true
  rescue AASM::InvalidTransition, RuntimeError => e
    raise "Cannot complete order: #{e.message}"
  end
end
