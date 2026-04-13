# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_07_110001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "balance_cents", default: 0, null: false
    t.string "balance_currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_accounts_on_user_id", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id"
    t.string "entity_type"
    t.string "ip_address"
    t.jsonb "metadata", default: {}
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["entity_type", "entity_id"], name: "index_audit_logs_on_entity_type_and_entity_id"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "idempotency_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.text "response_body", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_idempotency_keys_on_key", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.string "amount_currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.string "status", default: "created", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_providers", force: :cascade do |t|
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.integer "priority", default: 0, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active", "priority"], name: "index_payment_providers_on_is_active_and_priority"
    t.index ["name"], name: "index_payment_providers_on_name", unique: true
    t.index ["priority"], name: "index_payment_providers_on_priority"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "amount_cents", default: 0, null: false
    t.string "amount_currency", default: "USD", null: false
    t.bigint "balance_after_cents", default: 0, null: false
    t.string "balance_after_currency", default: "USD", null: false
    t.bigint "balance_before_cents", default: 0, null: false
    t.string "balance_before_currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "external_transaction_id"
    t.string "operation_type", null: false
    t.bigint "order_id", null: false
    t.string "provider_name"
    t.jsonb "provider_response", default: {}
    t.string "provider_status"
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_transactions_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["external_transaction_id"], name: "index_transactions_on_external_transaction_id"
    t.index ["order_id"], name: "index_transactions_on_order_id"
    t.index ["provider_name"], name: "index_transactions_on_provider_name"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "orders", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "orders"
end
