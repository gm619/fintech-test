FactoryBot.define do
  factory :transaction do
    account
    order
    amount_cents { 10_000 }
    operation_type { "debit" }
    balance_before_cents { 50_000 }
    balance_after_cents { 40_000 }
    description { "Test transaction" }
    provider_name { nil }
    external_transaction_id { nil }
    provider_status { nil }
    provider_response { {} }
  end
end
