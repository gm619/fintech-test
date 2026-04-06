FactoryBot.define do
  factory :account do
    user
    balance { 1000.00 }
  end
end
