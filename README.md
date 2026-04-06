# Fintech API

Ruby on Rails API-приложение для управления платежами, заказами и счетами пользователей.

## Технологии

- Ruby 3.4+
- Rails 8.1
- PostgreSQL
- RSpec для тестирования
- SolidQueue для background jobs
- SolidCache для кэширования

## Требования

- Ruby 3.4+
- PostgreSQL 15+
- Docker (опционально)

## Установка

```bash
# Установка зависимостей
bundle install

# Настройка базы данных
cp config/database.yml.example config/database.yml
# Отредактируйте config/database.yml с вашими настройками БД

# Создание и миграция БД
rails db:create db:migrate

# Запуск seed данных (опционально)
rails db:seed
```

## Запуск

```bash
# Локальный сервер
rails server

# Или через Docker
docker compose up
```

## API Endpoints

### Аутентификация

| Метод | Путь | Описание |
|-------|------|----------|
| POST | /api/v1/session | Вход (создание сессии) |
| DELETE | /api/v1/session | Выход (удаление сессии) |
| GET | /api/v1/session/current | Текущий пользователь |

**Пример входа:**
```bash
curl -X POST http://localhost:3000/api/v1/session \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'
```

### Заказы

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /api/v1/orders | Список заказов пользователя |
| GET | /api/v1/orders/:id | Детали заказа |
| POST | /api/v1/orders | Создание заказа |
| POST | /api/v1/orders/:id/complete | Завершение заказа (списание) |
| POST | /api/v1/orders/:id/cancel | Отмена заказа (возврат) |
| GET | /api/v1/orders/:id/payment_logs | История платежей по заказу |

**Пример создания заказа:**
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"order": {"amount": 100.00}}' \
  -b "_fintech_session=session_cookie"
```

### Счёт

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /api/v1/account | Информация о счёте |
| GET | /api/v1/account/transactions | История транзакций |

## Тестирование

```bash
# Запуск всех тестов
bundle exec rspec

# Запуск с покрытием
bundle exec rspec --coverage

# Запуск конкретного файла
bundle exec rspec spec/models/user_spec.rb
```

## CI/CD

Проект настроен на GitHub Actions с проверками:
- Brakeman (безопасность)
- Bundler Audit (уязвимости в гемах)
- Rubocop (стиль кода)
- RSpec (тесты)

## Структура проекта

```
app/
├── controllers/       # Контроллеры
│   └── api/v1/       # API v1 endpoints
├── models/           # Модели ActiveRecord
├── services/         # Бизнес-логика
├── jobs/             # Background jobs
config/
├── environments/     # Конфигурации окружений
├── initializers/     # Настройки
db/
├── migrate/          # Миграции БД
spec/                # Тесты RSpec
```

## Лицензия

MIT
