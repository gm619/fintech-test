FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }

    # Account создаётся автоматически через after_create callback
  end
end
