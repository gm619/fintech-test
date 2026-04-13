class Api::V1::OrdersController < ApplicationController
  before_action :require_user!
  rescue_from AASM::InvalidTransition, with: :render_conflict
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

  def index
    authorize Order
    page = [ params[:page].to_i, 1 ].max
    per_page = params[:per_page].to_i
    per_page = per_page.zero? ? 20 : per_page.clamp(1, 100)

    orders = current_user.orders.order(created_at: :desc)
    total = orders.count
    orders = orders.offset((page - 1) * per_page).limit(per_page)

    headers["X-Total-Count"] = total.to_s
    headers["X-Page"] = page.to_s
    headers["X-Per-Page"] = per_page.to_s

    render json: orders.map { |order| { id: order.id, amount: order.amount, status: order.status, created_at: order.created_at } }
  end

  def show
    order = Order.find(params[:id])
    authorize order
    render json: { id: order.id, amount: order.amount, status: order.status, created_at: order.created_at, updated_at: order.updated_at }
  end

  def create
    handle_idempotent_replay && return

    order = current_user.orders.build(order_params)
    order.status = "created"

    if order.save
      audit_log!("order_created", entity: order, metadata: { amount: order.amount })

      response = { id: order.id, status: order.status, amount: order.amount }
      store_idempotency(response, 201)

      render json: response, status: :created
    else
      render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def complete
    order = Order.find(params[:id])
    authorize order

    handle_idempotent_replay && return

    CompleteOrderService.new(order).call
    audit_log!("order_completed", entity: order, metadata: { amount: order.amount })

    response = { id: order.id, status: order.reload.status }
    store_idempotency(response, 200)

    render json: response
  rescue AASM::InvalidTransition, RuntimeError => e
    audit_log!("payment_failed", entity: order, metadata: { amount: order.amount, reason: e.message })
    raise e
  end

  def cancel
    order = Order.find(params[:id])
    authorize order

    handle_idempotent_replay && return

    CancelOrderService.new(order).call
    audit_log!("order_canceled", entity: order, metadata: { amount: order.amount })

    response = { id: order.id, status: order.reload.status }
    store_idempotency(response, 200)

    render json: response
  end

  def payment_logs
    order = Order.find(params[:id])
    authorize order
    render json: order.transactions.map { |t|
      {
        id: t.id,
        amount: t.amount,
        operation_type: t.operation_type,
        balance_before: t.balance_before,
        balance_after: t.balance_after,
        description: t.description,
        created_at: t.created_at
      }
    }
  end

  def payment_status
    order = Order.find(params[:id])
    authorize order

    attempts = order.transactions
      .where.not(provider_name: nil)
      .order(created_at: :desc)
      .map { |t|
        {
          id: t.id,
          provider: t.provider_name,
          external_transaction_id: t.external_transaction_id,
          provider_status: t.provider_status,
          amount: t.amount,
          operation_type: t.operation_type,
          created_at: t.created_at,
          error: t.provider_response&.dig("error")
        }
      }

    render json: {
      order_id: order.id,
      order_status: order.status,
      payment_attempts: attempts,
      latest_attempt: attempts.first
    }
  end

  private

  def handle_idempotent_replay
    idempotency_key = request.headers["Idempotency-Key"]
    return false unless idempotency_key.present?

    existing = IdempotencyKey.find_by(key: idempotency_key)
    return false unless existing

    render json: JSON.parse(existing.response_body), status: existing.status
    true
  end

  def store_idempotency(response, status)
    idempotency_key = request.headers["Idempotency-Key"]
    return unless idempotency_key.present?

    IdempotencyKey.create!(
      key: idempotency_key,
      status: status,
      response_body: response.to_json
    )
  rescue ActiveRecord::RecordNotUnique
    # Another request created the key first — ignore, response was already returned
  end

  def order_params
    params.require(:order).permit(:amount)
  end

  def render_conflict(exception)
    render json: { error: exception.message }, status: :conflict
  end

  def render_unprocessable_entity(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
