# frozen_string_literal: true

class Rack::Attack
  # Проверка SSL для production
  # В development/test можно отключить через env

  # Лимиты для API эндпоинтов
  # 100 запросов в минуту с одного IP
  throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api")
  end

  # Более строгий лимит для auth endpoints
  # 5 попыток в минуту
  throttle("auth/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.include?("/session") && req.post?
  end
end

# Включаем rack-attack в production и development
Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?
