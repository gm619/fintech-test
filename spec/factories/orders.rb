FactoryBot.define do
  factory :order do
    user
    amount { Money.new(15_000) }
    status { 'created' }
  end
end
