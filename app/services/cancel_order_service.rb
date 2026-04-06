class CancelOrderService
  def initialize(order)
    @order = order
    @user = order.user
  end

  def call
    raise "Order not successful" unless @order.successful?

    Account.transaction do
      account = @user.account
      # order.amount теперь объект Money благодаря money-rails
      account.credit!(@order.amount, @order, "Refund for order #{@order.id}")
      @order.cancel!
    end
    true
  rescue AASM::InvalidTransition, RuntimeError => e
    raise "Cannot cancel order: #{e.message}"
  end
end
