# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :response_body, presence: true
  validates :status, presence: true

  # Очистка старых ключей (старше 24 часов)
  def self.cleanup
    where('created_at < ?', 24.hours.ago).delete_all
  end
end
