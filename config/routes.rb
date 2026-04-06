Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :orders, only: [:create, :show, :index] do
        member do
          post :complete      # POST /api/v1/orders/:id/complete
          post :cancel        # POST /api/v1/orders/:id/cancel
          get  :payment_logs  # GET  /api/v1/orders/:id/payment_logs
        end
      end

      # Опционально: если нужен отдельный просмотр счетов или транзакций
      resource :account, only: [:show] do
        get :transactions
      end
    end
  end

  # Если вы не используете API-режим и хотите корневой путь
  # root "api/v1/orders#index"
end
