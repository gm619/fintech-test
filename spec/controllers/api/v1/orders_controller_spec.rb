# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:user) { create(:user) }
  let!(:account) { user.account }

  before do
    account.update!(balance: Money.new(500_00))
    create(:payment_provider, name: "internal_balance", type: "PaymentProvider::InternalBalance", priority: 0)
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
    allow_any_instance_of(OrderPolicy).to receive(:create?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:complete?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:cancel?).and_return(true)
  end

  describe "POST /api/v1/orders" do
    context "with valid params" do
      it "creates a new order" do
        expect {
          post "/api/v1/orders", params: { order: { amount: 100_00 } }, as: :json
        }.to change(Order, :count).by(1)
      end

      it "returns created status" do
        post "/api/v1/orders", params: { order: { amount: 100_00 } }, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context "with invalid amount (exceeds limit)" do
      it "does not create order" do
        expect {
          post "/api/v1/orders", params: { order: { amount: 2_000_000_000 } }, as: :json
        }.not_to change(Order, :count)
      end
    end
  end

  describe "POST /api/v1/orders/:id/complete" do
    let(:order) { create(:order, user: user, amount: Money.new(100_00), status: "created") }

    it "completes the order" do
      post "/api/v1/orders/#{order.id}/complete", as: :json
      expect(order.reload.status).to eq("successful")
    end

    it "debits the account" do
      expect {
        post "/api/v1/orders/#{order.id}/complete", as: :json
      }.to change { user.account.reload.balance }.by(Money.new(-100_00))
    end
  end

  describe "GET /api/v1/orders" do
    let!(:orders) { create_list(:order, 3, user: user) }

    it "returns all user orders" do
      get "/api/v1/orders", as: :json
      expect(response.parsed_body.size).to eq(3)
    end

    it "includes pagination headers" do
      get "/api/v1/orders", as: :json
      expect(response.headers["X-Total-Count"]).to eq("3")
      expect(response.headers["X-Page"]).to eq("1")
      expect(response.headers["X-Per-Page"]).to eq("20")
    end

    it "defaults to empty array when user has no orders" do
      user.orders.destroy_all
      get "/api/v1/orders", as: :json
      expect(response.parsed_body).to eq([])
    end

    it "returns correct total count header" do
      get "/api/v1/orders", as: :json
      expect(response.headers["X-Total-Count"]).to eq("3")
    end

    it "defaults to 20 per_page when not specified" do
      get "/api/v1/orders", as: :json
      expect(response.headers["X-Per-Page"]).to eq("20")
    end
  end

  describe "GET /api/v1/orders/:id" do
    let(:order) { create(:order, user: user) }

    it "returns the order" do
      get "/api/v1/orders/#{order.id}", as: :json
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for non-existent order" do
      get "/api/v1/orders/99999", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/orders/:id/payment_logs" do
    let!(:order) { create(:order, user: user, status: "created") }

    it "returns empty array when no transactions" do
      get "/api/v1/orders/#{order.id}/payment_logs", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns transactions for the order" do
      account.credit!(Money.new(50_00), order, "Test credit")
      account.debit!(Money.new(50_00), order, "Test debit")

      get "/api/v1/orders/#{order.id}/payment_logs", as: :json
      expect(response.parsed_body.size).to eq(2)
      expect(response.parsed_body.map { |t| t["operation_type"] }).to eq(%w[credit debit])
    end

    it "includes balance snapshots" do
      account.credit!(Money.new(50_00), order)

      get "/api/v1/orders/#{order.id}/payment_logs", as: :json
      tx = response.parsed_body.first
      expect(tx).to include("balance_before", "balance_after", "created_at")
    end
  end

  describe "POST /api/v1/orders/:id/cancel" do
    let(:order) { create(:order, user: user, amount: Money.new(100_00), status: "successful") }

    before do
      # Create a payment transaction so CancelOrderService can refund
      order.transactions.create!(
        account: account,
        amount_cents: 100_00,
        operation_type: "debit",
        balance_before_cents: account.balance.cents,
        balance_after_cents: account.balance.cents,
        description: "Payment for order #{order.id}",
        provider_name: "internal_balance",
        provider_status: "succeeded"
      )
    end

    it "cancels the order and refunds" do
      post "/api/v1/orders/#{order.id}/cancel", as: :json
      expect(order.reload.status).to eq("canceled")
    end
  end

  describe "Authorization" do
    let(:other_user) { create(:user) }
    let!(:other_order) { create(:order, user: other_user, amount: Money.new(50_00), status: "created") }

    # Override parent stubs by explicitly resetting them
    before do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
      # Reset policy stubs to NOT stub (use real policy)
      allow_any_instance_of(OrderPolicy).to receive(:show?).and_call_original
      allow_any_instance_of(OrderPolicy).to receive(:complete?).and_call_original
      allow_any_instance_of(OrderPolicy).to receive(:cancel?).and_call_original
      allow_any_instance_of(OrderPolicy).to receive(:payment_logs?).and_call_original
    end

    describe "GET /api/v1/orders/:id" do
      it "returns 403 for another user's order" do
        get "/api/v1/orders/#{other_order.id}", as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/v1/orders/:id/complete" do
      it "returns 403 for another user's order" do
        post "/api/v1/orders/#{other_order.id}/complete", as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/v1/orders/:id/cancel" do
      let!(:other_order) { create(:order, user: other_user, amount: Money.new(50_00), status: "successful") }

      it "returns 403 for another user's order" do
        post "/api/v1/orders/#{other_order.id}/cancel", as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /api/v1/orders/:id/payment_logs" do
      it "returns 403 for another user's order" do
        get "/api/v1/orders/#{other_order.id}/payment_logs", as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "Idempotency" do
    let(:order) { create(:order, user: user, amount: Money.new(100_00), status: "created") }
    let(:idempotency_key) { "test-key-123" }

    describe "POST /api/v1/orders with Idempotency-Key" do
      it "creates order on first request" do
        post "/api/v1/orders",
             params: { order: { amount: 100_00 } },
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        expect(response).to have_http_status(:created)
        expect(IdempotencyKey.count).to eq(1)
      end

      it "returns cached response on replay" do
        post "/api/v1/orders",
             params: { order: { amount: 100_00 } },
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        expect {
          post "/api/v1/orders",
               params: { order: { amount: 100_00 } },
               headers: { "Idempotency-Key" => idempotency_key },
               as: :json
        }.not_to change(Order, :count)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["id"]).to eq(Order.first.id)
      end

      it "stores HTTP status as integer" do
        post "/api/v1/orders",
             params: { order: { amount: 100_00 } },
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        key = IdempotencyKey.last
        expect(key.status).to eq(201)
        expect(key.status).to be_a(Integer)
      end
    end

    describe "POST /api/v1/orders/:id/complete with Idempotency-Key" do
      it "completes on first request and stores key" do
        post "/api/v1/orders/#{order.id}/complete",
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(IdempotencyKey.count).to eq(1)
      end

      it "returns cached response without re-executing" do
        post "/api/v1/orders/#{order.id}/complete",
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        balance_after_first = user.account.reload.balance

        expect {
          post "/api/v1/orders/#{order.id}/complete",
               headers: { "Idempotency-Key" => idempotency_key },
               as: :json
        }.not_to change { user.account.reload.balance }

        expect(response).to have_http_status(:ok)
        expect(user.account.balance).to eq(balance_after_first)
      end
    end

    describe "POST /api/v1/orders/:id/cancel with Idempotency-Key" do
      let(:order) { create(:order, user: user, amount: Money.new(100_00), status: "successful") }

      before do
        order.transactions.create!(
          account: user.account,
          amount_cents: 100_00,
          operation_type: "debit",
          balance_before_cents: user.account.balance.cents,
          balance_after_cents: user.account.balance.cents,
          description: "Payment for order #{order.id}",
          provider_name: "internal_balance",
          provider_status: "succeeded"
        )
      end

      it "cancels on first request and stores key" do
        post "/api/v1/orders/#{order.id}/cancel",
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(IdempotencyKey.count).to eq(1)
      end

      it "returns cached response without re-executing" do
        post "/api/v1/orders/#{order.id}/cancel",
             headers: { "Idempotency-Key" => idempotency_key },
             as: :json

        balance_after_first = user.account.reload.balance

        expect {
          post "/api/v1/orders/#{order.id}/cancel",
               headers: { "Idempotency-Key" => idempotency_key },
               as: :json
        }.not_to change { user.account.reload.balance }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
