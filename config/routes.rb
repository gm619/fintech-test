Rails.application.routes.draw do
  get "/up", to: "health_check#show"

  namespace :api do
    namespace :v1 do
      resource :session, only: [ :create, :destroy ] do
        get :current, on: :collection
      end

      resources :orders, only: [ :create, :show, :index ] do
        member do
          post :complete
          post :cancel
          get :payment_logs
          get :payment_status
        end
      end

      resource :account, only: [ :show ] do
        get :transactions
      end

      resources :payment_providers, only: [ :index ]
    end
  end

  namespace :webhooks do
    post "stripe", to: "stripe#create"
    post "paypal", to: "paypal#create"
  end
end
