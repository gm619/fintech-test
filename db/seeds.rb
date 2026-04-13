FactoryBot.create(:user,
    email: 'admin@example.com',
    password: 'password123')

PaymentProvider.seed_defaults
