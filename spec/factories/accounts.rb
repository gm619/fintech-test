FactoryBot.define do
  factory :account do
    user
    balance { Money.new(100_000) }
  end
end
