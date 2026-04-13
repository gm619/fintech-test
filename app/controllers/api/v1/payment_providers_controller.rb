class Api::V1::PaymentProvidersController < ApplicationController
  before_action :require_user!

  def index
    providers = PaymentProvider.active.ordered_by_priority
    render json: providers.map { |p|
      {
        name: p.name,
        type: p.type.demodulize,
        priority: p.priority,
        is_active: p.is_active
      }
    }
  end
end
