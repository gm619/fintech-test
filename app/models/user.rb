class User < ApplicationRecord
  has_secure_password

  has_one :account, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

  after_create :create_account!

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
