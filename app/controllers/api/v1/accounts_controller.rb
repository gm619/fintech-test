class Api::V1::AccountsController < ApplicationController
  before_action :require_user!

  def show
    authorize current_user.account
    render json: {
      id: current_user.account.id,
      balance: current_user.account.balance,
      user_email: current_user.email
    }
  end

  def transactions
    authorize current_user.account
    transactions = current_user.account.transactions.order(created_at: :desc)
    render json: transactions.map { |t|
      {
        id: t.id,
        amount: t.amount,
        operation_type: t.operation_type,
        balance_before: t.balance_before,
        balance_after: t.balance_after,
        description: t.description,
        order_id: t.order_id,
        created_at: t.created_at
      }
    }
  end
end
