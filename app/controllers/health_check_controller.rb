# frozen_string_literal: true

class HealthCheckController < ApplicationController
  skip_before_action :require_user!, raise: false

  def show
    # Проверяем подключение к БД
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: { status: "ok", timestamp: Time.current }, status: :ok
  rescue ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::ConnectionNotEstablished
    render json: { status: "error", error: "database_unavailable" }, status: :service_unavailable
  end
end
