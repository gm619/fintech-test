class Webhooks::BaseController < ActionController::API
  # No CSRF check needed for webhooks — we verify signatures ourselves

  private

  def render_success(message = "Webhook received")
    render json: { status: "ok", message: message }, status: :ok
  end

  def render_error(message, status: :bad_request)
    render json: { status: "error", message: message }, status: status
  end

  def record_webhook_event(event_type, payload)
    AuditLog.log!(
      user: nil,
      action: "webhook_received",
      entity: nil,
      metadata: {
        event_type: event_type,
        provider: self.class.name.demodulize,
        payload_summary: payload.slice(:id, :status, :amount)
      },
      request: request
    )
  rescue => e
    Rails.logger.error("Failed to write webhook audit log: #{e.message}")
  end
end
