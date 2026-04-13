# frozen_string_literal: true

class IdempotencyKeyCleanupJob < ApplicationJob
  queue_as :default

  def perform
    IdempotencyKey.cleanup
  end
end
