class PaymentProvider::Stripe < PaymentProvider
  # Process payment via Stripe Charges API.
  def process_payment(order, account)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    stripe = build_client
    amount_cents = order.amount.cents

    charge_options = {
      amount: amount_cents,
      currency: "usd",
      description: "Order #{order.id} payment",
      metadata: { order_id: order.id, user_id: account.user_id }
    }

    charge_options[:customer] = account.stripe_customer_id if account.respond_to?(:stripe_customer_id) && account.stripe_customer_id
    charge_options[:receipt_email] = account.user.email if account.user.respond_to?(:email) && account.user.email

    charge = stripe::Charge.create(charge_options)

    transaction = account.transactions.create!(
      order: order,
      amount_cents: amount_cents,
      operation_type: "debit",
      balance_before_cents: account.balance.cents,
      balance_after_cents: account.balance.cents,
      description: "Order #{order.id} payment via Stripe",
      provider_name: name,
      external_transaction_id: charge.id,
      provider_status: charge.status,
      provider_response: charge.to_h
    )

    { success: true, transaction: transaction, error: nil, reason: nil }
  rescue ::Stripe::CardError => e
    fail_result(card_error_message(e), :card_declined)
  rescue ::Stripe::InvalidRequestError => e
    fail_result(e.message, :invalid_request)
  rescue ::Stripe::StripeError => e
    fail_result(e.message, :provider_error)
  rescue ActiveRecord::RecordInvalid => e
    fail_result(e.message, :provider_error)
  end

  def refund(original_transaction)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    external_id = original_transaction.external_transaction_id
    raise "No external transaction ID to refund" unless external_id

    stripe = build_client
    refund = stripe::Refund.create(charge: external_id)

    account = original_transaction.account
    amount = original_transaction.amount

    refund_transaction = account.transactions.create!(
      order: original_transaction.order,
      amount_cents: amount.cents,
      operation_type: "credit",
      balance_before_cents: account.balance.cents,
      balance_after_cents: account.balance.cents,
      description: "Refund for order #{original_transaction.order_id} via Stripe",
      provider_name: name,
      external_transaction_id: refund.id,
      provider_status: refund.status,
      provider_response: refund.to_h
    )

    { success: true, transaction: refund_transaction, error: nil }
  rescue ::Stripe::StripeError => e
    fail_result(e.message, :provider_error)
  rescue ActiveRecord::RecordInvalid => e
    fail_result(e.message, :provider_error)
  end

  def status(external_transaction_id)
    stripe = build_client
    charge = stripe::Charge.retrieve(external_transaction_id)
    { status: charge.status, details: charge.to_h }
  rescue ::Stripe::StripeError => e
    { status: "error", details: { error: e.message } }
  end

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

  def self.verify_webhook_signature(payload, sig_header, webhook_secret)
    ::Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
  rescue JSON::ParserError => e
    raise "Invalid payload: #{e.message}"
  rescue ::Stripe::SignatureVerificationError => e
    raise "Invalid signature: #{e.message}"
  end

  private

  def build_client
    secret_key = config["secret_key"] || config[:secret_key] || Rails.application.credentials.dig(:stripe, :secret_key)
    raise "Stripe secret_key not configured" unless secret_key

    ::Stripe.api_key = secret_key
    ::Stripe
  end

  def card_error_message(exception)
    case exception.code
    when "card_declined"
      "Your card was declined."
    when "expired_card"
      "Your card has expired."
    when "incorrect_cvc"
      "Your card's security code is incorrect."
    when "processing_error"
      "An error occurred while processing your card."
    else
      exception.message
    end
  end

  def fail_result(error, reason)
    { success: false, transaction: nil, error: error, reason: reason }
  end
end
