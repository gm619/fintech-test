# Eager load payment provider STI subclasses so Rails can find them
# when reading the type column from the database.
Rails.application.reloader.to_prepare do
  PaymentProvider::InternalBalance
  PaymentProvider::Stripe
  PaymentProvider::PayPal
end
