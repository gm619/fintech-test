# frozen_string_literal: true

class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotency_keys do |t|
      t.string :key, null: false
      t.integer :status, null: false
      t.text :response_body, null: false
      t.timestamps
    end

    add_index :idempotency_keys, :key, unique: true
  end
end
