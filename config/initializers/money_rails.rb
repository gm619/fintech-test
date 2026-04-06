# frozen_string_literal: true

MoneyRails.configure do |config|
  # Настройка валюты по умолчанию
  config.default_currency = :usd

  # Использовать银行 для округления (banker's rounding)
  config.rounding_mode = BigDecimal::ROUND_HALF_EVEN

  # Сохранять валюту в БД (опционально)
  # config.include_currency_in_migration = true

  # Настройки форматирования
  # config.number_format = {
  #   # Количество знаков после запятой
  #   decimal_mark: '.',
  #   # Разделитель тысяч
  #   delimiter: ',',
  #   # Количество знаков после запятой
  #   precision: 2
  # }

  # Настройки для представления (опционально)
  # config.currency_format = {
  #   # Формат отображения: $1.00 или 1.00 USD
  #   format: '%u%n',
  #   # Разделитель
  #   no_cents: false,
  #   # Символ валюты
  #   symbol: true
  # }
end
