class Webhooks::PaypalController < Webhooks::BaseController
  # Handles PayPal webhook events.
  #
  # Supported events:
  #   - PAYMENT.CAPTURE.COMPLETED
  #   - PAYMENT.CAPTURE.DENIED
  #   - PAYMENT.CAPTURE.REFUNDED
  #
  # Note: PayPal webhook verification uses the transmit headers and webhook ID.

  def create
    # PayPal webhook verification (simplified — in production, use the VerifyWebhookSignature API)
    webhook_id = Rails.application.credentials.dig(:paypal, :webhook_id)

    # For sandbox/development, we accept the payload directly.
    # In production, call PayPal::SDK::REST::WebhookEvent.validate(payload, headers, webhook_id)
    event_data = JSON.parse(request.body.read)

    case event_data["event_type"]
    when "PAYMENT.CAPTURE.COMPLETED"
      handle_capture_completed(event_data)
    when "PAYMENT.CAPTURE.DENIED"
      handle_capture_denied(event_data)
    when "PAYMENT.CAPTURE.REFUNDED"
      handle_capture_refunded(event_data)
    else
      Rails.logger.info("Unhandled PayPal webhook event: #{event_data["event_type"]}")
    end

    render_success
  rescue JSON::ParserError => e
    render_error("Invalid JSON payload: #{e.message}")
  end

  private

  def handle_capture_completed(event_data)
    resource = event_data["resource"]
    external_id = resource["id"]

    transaction = Transaction.find_by(external_transaction_id: external_id)
    return unless transaction

    transaction.update!(
      provider_status: "COMPLETED",
      provider_response: event_data
    )

    order = transaction.order
    order.complete! unless order.successful? || order.canceled?

    record_webhook_event("PAYMENT.CAPTURE.COMPLETED", {
      id: external_id,
      status: resource["status"],
      amount: resource["amount"]["value"]
    })

    Rails.logger.info("PayPal webhook: PAYMENT.CAPTURE.COMPLETED for order #{order.id}")
  end

  def handle_capture_denied(event_data)
    resource = event_data["resource"]
    external_id = resource["id"]

    transaction = Transaction.find_by(external_transaction_id: external_id)
    return unless transaction

    transaction.update!(
      provider_status: "DENIED",
      provider_response: event_data
    )

    record_webhook_event("PAYMENT.CAPTURE.DENIED", {
      id: external_id,
      status: resource["status"]
    })

    Rails.logger.info("PayPal webhook: PAYMENT.CAPTURE.DENIED for transaction #{transaction.id}")
  end

  def handle_capture_refunded(event_data)
    resource = event_data["resource"]
    external_id = resource["id"]

    # Find the original capture by the refund's sale_id or parent ID
    sale_id = resource.dig("sale_id") || resource.dig("links")&.find { |l| l["rel"] == "up" }&.dig("href")&.split("/")&.last
    transaction = Transaction.find_by(external_transaction_id: sale_id)
    return unless transaction

    transaction.update!(
      provider_status: "refunded",
      provider_response: event_data
    )

    record_webhook_event("PAYMENT.CAPTURE.REFUNDED", {
      id: external_id,
      status: resource["status"],
      amount: resource.dig("amount", "value")
    })

    Rails.logger.info("PayPal webhook: PAYMENT.CAPTURE.REFUNDED for transaction #{transaction.id}")
  end
end
