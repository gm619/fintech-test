class Api::V1::OrdersController < ApplicationController
  before_action :require_user!
  rescue_from StandardError, with: :render_error

  def index
    authorize Order
    orders = current_user.orders.order(created_at: :desc)
    render json: orders.map { |order| { id: order.id, amount: order.amount, status: order.status, created_at: order.created_at } }
  end

  def show
    order = current_user.orders.find(params[:id])
    authorize order
    render json: { id: order.id, amount: order.amount, status: order.status, created_at: order.created_at, updated_at: order.updated_at }
  end

  def create
    # Идемпотентность: проверяем ключ в заголовке
    idempotency_key = request.headers["Idempotency-Key"]
    if idempotency_key.present?
      existing = IdempotencyKey.find_by(key: idempotency_key)
      if existing
        return render json: JSON.parse(existing.response_body), status: existing.status
      end
    end

    order = current_user.orders.build(order_params)
    order.status = "created"

    if order.save
      audit_log!("order_created", entity: order, metadata: { amount: order.amount })

      response = { id: order.id, status: order.status, amount: order.amount }

      # Сохраняем идемпотентный ключ
      if idempotency_key.present?
        IdempotencyKey.create!(
          key: idempotency_key,
          status: :created,
          response_body: response.to_json
        )
      end

      render json: response, status: :created
    else
      render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def complete
    order = current_user.orders.find(params[:id])
    authorize order

    # Идемпотентность
    idempotency_key = request.headers["Idempotency-Key"]
    if idempotency_key.present?
      existing = IdempotencyKey.find_by(key: idempotency_key)
      if existing
        return render json: JSON.parse(existing.response_body), status: existing.status
      end
    end

    CompleteOrderService.new(order).call
    audit_log!("order_completed", entity: order, metadata: { amount: order.amount })

    response = { id: order.id, status: order.reload.status }

    if idempotency_key.present?
      IdempotencyKey.create!(
        key: idempotency_key,
        status: :ok,
        response_body: response.to_json
      )
    end

    render json: response
  rescue AASM::InvalidTransition, RuntimeError => e
    audit_log!("payment_failed", entity: order, metadata: { amount: order.amount, reason: e.message })
    raise e
  end

  def cancel
    order = current_user.orders.find(params[:id])
    authorize order
    CancelOrderService.new(order).call
    audit_log!("order_canceled", entity: order, metadata: { amount: order.amount })
    render json: { id: order.id, status: order.reload.status }
  end

  def payment_logs
    order = current_user.orders.find(params[:id])
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

  private

  def order_params
    params.require(:order).permit(:amount)
  end

  def render_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
