class PaymentProvider::PayPal < PaymentProvider
  # Process payment via PayPal Orders v2 API.
  def process_payment(order, account)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    paypal_api = build_api

    order_request = PayPal::SDK::REST::Order.new({
      intent: "CAPTURE",
      purchase_units: [ {
        reference_id: "order_#{order.id}",
        amount: {
          currency_code: "USD",
          value: order.amount.to_f.to_s
        }
      } ],
      application_context: {
        brand_name: config[:brand_name] || "Fintech API",
        return_url: config[:return_url] || "https://example.com/return",
        cancel_url: config[:cancel_url] || "https://example.com/cancel"
      }
    })

    created_order = order_request.create
    raise "Failed to create PayPal order: #{created_order.error.inspect}" unless created_order.success?

    captured_order = created_order.capture
    raise "Failed to capture PayPal order: #{captured_order.error.inspect}" unless captured_order.success?

    purchase_unit = captured_order.purchase_units&.first
    capture_data = purchase_unit&.payments&.captures&.first

    transaction = account.transactions.create!(
      order: order,
      amount_cents: order.amount.cents,
      operation_type: "debit",
      balance_before_cents: account.balance.cents,
      balance_after_cents: account.balance.cents,
      description: "Order #{order.id} payment via PayPal",
      provider_name: name,
      external_transaction_id: capture_data&.id,
      provider_status: capture_data&.status,
      provider_response: captured_order.to_h
    )

    { success: true, transaction: transaction, error: nil, reason: nil }
  rescue ::PayPal::SDK::REST::Error => e
    fail_result(paypal_error_message(e), :provider_error)
  rescue ActiveRecord::RecordInvalid => e
    fail_result(e.message, :provider_error)
  rescue RuntimeError => e
    fail_result(e.message, :provider_error)
  end

  def refund(original_transaction)
    return fail_result("Provider is not active", :provider_inactive) unless is_active

    external_id = original_transaction.external_transaction_id
    raise "No external transaction ID to refund" unless external_id

    paypal_api = build_api

    refund_request = PayPal::SDK::REST::Refund.new({
      amount: {
        currency_code: "USD",
        value: original_transaction.amount.to_f.to_s
      }
    })

    capture = PayPal::SDK::REST::Payment.get(external_id)
    captured_refund = refund_request.save(capture_id: external_id)
    raise "Failed to refund PayPal capture: #{captured_refund.error.inspect}" unless captured_refund.success?

    account = original_transaction.account
    amount = original_transaction.amount

    refund_transaction = account.transactions.create!(
      order: original_transaction.order,
      amount_cents: amount.cents,
      operation_type: "credit",
      balance_before_cents: account.balance.cents,
      balance_after_cents: account.balance.cents,
      description: "Refund for order #{original_transaction.order_id} via PayPal",
      provider_name: name,
      external_transaction_id: captured_refund.id,
      provider_status: captured_refund.status,
      provider_response: captured_refund.to_h
    )

    { success: true, transaction: refund_transaction, error: nil }
  rescue ::PayPal::SDK::REST::Error => e
    fail_result(paypal_error_message(e), :provider_error)
  rescue ActiveRecord::RecordInvalid => e
    fail_result(e.message, :provider_error)
  end

  def status(external_transaction_id)
    paypal_api = build_api
    order = PayPal::SDK::REST::Order.find(external_transaction_id)
    { status: order.status, details: order.to_h }
  rescue ::PayPal::SDK::REST::Error => e
    { status: "error", details: { error: paypal_error_message(e) } }
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

  private

  def build_api
    client_id = config["client_id"] || config[:client_id] || Rails.application.credentials.dig(:paypal, :client_id)
    secret = config["secret"] || config[:secret] || Rails.application.credentials.dig(:paypal, :secret)
    mode = config["mode"] || config[:mode] || :sandbox

    raise "PayPal client_id not configured" unless client_id
    raise "PayPal secret not configured" unless secret

    PayPal::SDK.configure(
      mode: mode.to_s,
      client_id: client_id,
      client_secret: secret,
      logger: Rails.logger,
      log_level: :warn
    )

    PayPal::SDK::REST
  end

  def paypal_error_message(exception)
    exception.message || "PayPal API error"
  end

  def fail_result(error, reason)
    { success: false, transaction: nil, error: error, reason: reason }
  end
end
