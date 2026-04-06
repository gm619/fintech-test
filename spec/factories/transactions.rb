FactoryBot.define do
  factory :transaction do
    account
    order
    amount { Money.new(10_000) }
    operation_type { "debit" }
    balance_before { Money.new(50_000) }
    balance_after { Money.new(40_000) }
    description { "Test transaction" }
  end
end
