class Webhooks::StripeController < Webhooks::BaseController
  # Handles Stripe webhook events.
  # Verify signature, then process the event.
  #
  # Supported events:
  #   - payment_intent.succeeded
  #   - payment_intent.payment_failed
  #   - charge.refunded
  #   - charge.failed

  def create
    payload = request.body.read
    sig_header = request.headers["Stripe-Signature"]

    webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)
    return render_error("Stripe webhook secret not configured", status: :internal_server_error) unless webhook_secret

    begin
      event = PaymentProvider::Stripe.verify_webhook_signature(payload, sig_header, webhook_secret)
    rescue => e
      Rails.logger.error("Stripe webhook signature verification failed: #{e.message}")
      return render_error("Invalid webhook signature", status: :bad_request)
    end

    case event.type
    when "payment_intent.succeeded"
      handle_payment_succeeded(event.data.object)
    when "payment_intent.payment_failed"
      handle_payment_failed(event.data.object)
    when "charge.refunded"
      handle_charge_refunded(event.data.object)
    else
      Rails.logger.info("Unhandled Stripe webhook event: #{event.type}")
    end

    render_success
  end

  private

  def handle_payment_succeeded(payment_intent)
    # Find transaction by latest_charge or payment intent ID
    transaction = Transaction.find_by(external_transaction_id: payment_intent.latest_charge) ||
                  Transaction.find_by(external_transaction_id: payment_intent.id)
    return unless transaction

    transaction.update!(
      provider_status: "succeeded",
      provider_response: payment_intent.to_h
    )

    order = transaction.order
    order.complete! unless order.successful? || order.canceled?

    record_webhook_event("payment_intent.succeeded", {
      id: payment_intent.id,
      status: payment_intent.status,
      amount: payment_intent.amount
    })

    Rails.logger.info("Stripe webhook: payment_intent.succeeded for order #{order.id}")
  end

  def handle_payment_failed(payment_intent)
    order = find_order_by_payment_intent(payment_intent.id)
    return unless order

    transaction = order.transactions.find_by(external_transaction_id: payment_intent.latest_charge)

    if transaction
      transaction.update!(
        provider_status: "failed",
        provider_response: payment_intent.to_h
      )
    end

    record_webhook_event("payment_intent.payment_failed", {
      id: payment_intent.id,
      status: payment_intent.status,
      error: payment_intent.last_payment_error&.message
    })

    Rails.logger.info("Stripe webhook: payment_intent.payment_failed for order #{order.id}")
  end

  def handle_charge_refunded(charge)
    transaction = Transaction.find_by(external_transaction_id: charge.id)
    return unless transaction

    transaction.update!(
      provider_status: "refunded",
      provider_response: charge.to_h
    )

    record_webhook_event("charge.refunded", {
      id: charge.id,
      status: charge.status,
      amount_refunded: charge.amount_refunded
    })

    Rails.logger.info("Stripe webhook: charge.refunded for transaction #{transaction.id}")
  end

  def find_order_by_payment_intent(payment_intent_id)
    transaction = Transaction.find_by(external_transaction_id: payment_intent_id)
    transaction&.order ||
      Transaction.find_by(provider_response: { payment_intent: payment_intent_id })&.order
  end
end
