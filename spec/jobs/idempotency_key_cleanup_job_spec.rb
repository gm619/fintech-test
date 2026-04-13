# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyKeyCleanupJob, type: :job do
  it "calls IdempotencyKey.cleanup" do
    expect(IdempotencyKey).to receive(:cleanup)
    described_class.perform_now
  end
end
