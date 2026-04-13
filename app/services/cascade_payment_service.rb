class CascadePaymentService
  # Tries payment providers in priority order until one succeeds.
  # Returns { success: bool, transaction: Transaction, error: String, attempts: Array }
  #
  # Usage:
  #   result = CascadePaymentService.new(order, account).call
  #   if result[:success]
  #     order.complete!
  #   end

  attr_reader :order, :account, :attempts

  def initialize(order, account)
    @order = order
    @account = account
    @attempts = []
  end

  def call
    providers = PaymentProvider.available_providers

    if providers.empty?
      return {
        success: false,
        transaction: nil,
        error: "No payment providers configured",
        attempts: @attempts
      }
    end

    providers.each do |provider|
      result = process_with_provider(provider)

      if result[:success]
        audit_success(result[:transaction])
        return { success: true, transaction: result[:transaction], error: nil, attempts: @attempts }
      else
        @attempts << {
          provider: provider.name,
          success: false,
          error: result[:error],
          reason: result[:reason]
        }
        audit_attempt(provider, result)

        # Don't retry on non-retryable reasons
        # next if provider.retryable_reason?(result[:reason])

        # Provider error that shouldn't be retried — stop cascade
        return {
          success: false,
          transaction: nil,
          error: "Payment failed on #{provider.name}: #{result[:error]}",
          attempts: @attempts
        } unless provider.retryable_reason?(result[:reason])
      end
    end

    # All providers failed with retryable reasons
    {
      success: false,
      transaction: nil,
      error: "All payment providers failed: #{@attempts.map { |a| "#{a[:provider]}: #{a[:error]}" }.join("; ")}",
      attempts: @attempts
    }
  rescue ActiveRecord::Deadlocked
    { success: false, transaction: nil, error: "Database deadlock during payment", attempts: @attempts }
  rescue ActiveRecord::StatementInvalid => e
    { success: false, transaction: nil, error: "Database error: #{e.message}", attempts: @attempts }
  rescue => e
    { success: false, transaction: nil, error: "Payment cascade failed: #{e.message}", attempts: @attempts }
  end

  private

  def process_with_provider(provider)
    provider.process_payment(@order, @account)
  rescue => e
    { success: false, transaction: nil, error: e.message, reason: :provider_error }
  end

  def audit_success(transaction)
    audit_log!(
      action: "payment_succeeded",
      entity: @order,
      metadata: {
        provider: transaction.provider_name,
        external_transaction_id: transaction.external_transaction_id,
        amount_cents: transaction.amount_cents
      }
    )
  end

  def audit_attempt(provider, result)
    audit_log!(
      action: "payment_attempt",
      entity: @order,
      metadata: {
        provider: provider.name,
        success: false,
        error: result[:error],
        reason: result[:reason]
      }
    )
  end

  def audit_log!(action:, entity:, metadata:)
    AuditLog.log!(
      user: @order.user,
      action: action,
      entity: entity,
      metadata: metadata,
      request: RequestStore.store[:audit_request]
    )
  rescue => e
    Rails.logger.error("Failed to write audit log: #{e.message}")
  end
end
