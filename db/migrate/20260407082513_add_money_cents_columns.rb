# frozen_string_literal: true

class AddMoneyCentsColumns < ActiveRecord::Migration[8.1]
  def change
    add_monetize :orders, :amount, amount: { null: false, default: 0 }
    add_monetize :accounts, :balance, amount: { null: false, default: 0 }
    add_monetize :transactions, :amount, amount: { null: false }
    add_monetize :transactions, :balance_before, amount: { null: false }
    add_monetize :transactions, :balance_after, amount: { null: false }
  end
end
