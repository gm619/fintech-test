# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:user) { create(:user) }
  let!(:account) { user.account }

  # Устанавливаем сессию для аутентификации
  before do
    account.update!(balance: Money.new(500_00))
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ user_id: user.id })
    # Разрешаем все действия для тестов (Pundit policy)
    allow_any_instance_of(OrderPolicy).to receive(:create?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:complete?).and_return(true)
    allow_any_instance_of(OrderPolicy).to receive(:cancel?).and_return(true)
  end

  describe 'POST /api/v1/orders' do
    context 'with valid params' do
      it 'creates a new order' do
        expect {
          post '/api/v1/orders', params: { order: { amount: 100_00 } }, as: :json
        }.to change(Order, :count).by(1)
      end

      it 'returns created status' do
        post '/api/v1/orders', params: { order: { amount: 100_00 } }, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid amount (exceeds limit)' do
      it 'does not create order' do
        expect {
          post '/api/v1/orders', params: { order: { amount: 2_000_000_000 } }, as: :json
        }.not_to change(Order, :count)
      end
    end
  end

  describe 'POST /api/v1/orders/:id/complete' do
    let(:order) { create(:order, user: user, amount: Money.new(100_00), status: 'created') }

    it 'completes the order' do
      post "/api/v1/orders/#{order.id}/complete", as: :json
      expect(order.reload.status).to eq('successful')
    end

    it 'debits the account' do
      expect {
        post "/api/v1/orders/#{order.id}/complete", as: :json
      }.to change { user.account.reload.balance }.by(Money.new(-100_00))
    end
  end

  describe 'GET /api/v1/orders' do
    let!(:orders) { create_list(:order, 3, user: user) }

    it 'returns all user orders' do
      get '/api/v1/orders', as: :json
      expect(response.parsed_body.size).to eq(3)
    end
  end

  describe 'GET /api/v1/orders/:id' do
    let(:order) { create(:order, user: user) }

    it 'returns the order' do
      get "/api/v1/orders/#{order.id}", as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/orders/:id/cancel' do
    # CancelOrderService требует successful статус (это возврат денег)
    let(:order) { create(:order, user: user, amount: Money.new(100_00), status: 'successful') }

    it 'cancels the order and refunds' do
      post "/api/v1/orders/#{order.id}/cancel", as: :json
      expect(order.reload.status).to eq('canceled')
    end
  end
end
