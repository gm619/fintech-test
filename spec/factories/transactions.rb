FactoryBot.define do
  factory :transaction do
    account
    order
    amount { 100.00 }
    operation_type { "debit" }
    balance_before { 500.00 }
    balance_after { 400.00 }
    description { "Test transaction" }
  end
end
