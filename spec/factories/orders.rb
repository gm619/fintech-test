FactoryBot.define do
  factory :order do
    user
    amount { 150.00 }
    status { 'created' }
  end
end
