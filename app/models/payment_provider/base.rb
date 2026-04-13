class PaymentProvider
  class Base
    # Each concrete provider is initialized with its PaymentProvider ActiveRecord record
    attr_reader :record

    def initialize(record)
      @record = record
    end

    def name
      record.name
    end

    def config
      record.config || {}
    end

    # Process a payment for an order.
    # Returns: { success: bool, transaction: Transaction, error: String, reason: Symbol }
    #
    # reason symbols:
    #   :insufficient_funds  — user has no funds (internal) or card declined
    #   :provider_error      — provider-side error (timeout, API error)
    #   :invalid_request     — bad input
    #   :fraud_suspected     — fraud detection triggered (no retry)
    #   :provider_inactive   — this provider is not active (no retry)
    def process_payment(order, account)
      raise NotImplementedError, "#{self.class} must implement #process_payment"
    end

    # Refund a previously processed transaction.
    # Returns: { success: bool, transaction: Transaction, error: String }
    def refund(original_transaction)
      raise NotImplementedError, "#{self.class} must implement #refund"
    end

    # Check status of an external transaction by ID.
    # Returns: { status: String, details: Hash }
    def status(external_transaction_id)
      raise NotImplementedError, "#{self.class} must implement #status"
    end

    # Whether errors from this provider should trigger cascade retry
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
  end
end
