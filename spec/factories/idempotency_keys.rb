# frozen_string_literal: true

FactoryBot.define do
  factory :idempotency_key do
    sequence(:key) { |n| "idem-key-#{n}-#{SecureRandom.uuid}" }
    status { :ok }
    sequence(:response_body) { |n| { id: n, status: "success" }.to_json }
  end
end
