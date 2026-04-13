FactoryBot.define do
  factory :payment_provider do
    sequence(:name) { |n| "provider_#{n}" }
    type { "PaymentProvider::InternalBalance" }
    priority { 0 }
    is_active { true }
    config { {} }

    initialize_with do
      klass = type.constantize
      klass.new(name: name, priority: priority, is_active: is_active, config: config)
    end

    trait :stripe do
      name { "stripe" }
      type { "PaymentProvider::Stripe" }
      priority { 10 }
      config { { secret_key: "sk_test_fake", webhook_secret: "whsec_test" } }
    end

    trait :paypal do
      name { "paypal" }
      type { "PaymentProvider::PayPal" }
      priority { 20 }
      config { { client_id: "fake_client_id", secret: "fake_secret", mode: "sandbox" } }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
