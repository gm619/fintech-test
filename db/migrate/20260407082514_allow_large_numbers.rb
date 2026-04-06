class AllowLargeNumbers < ActiveRecord::Migration[8.1]
  def up
    safety_assured {
      change_column :orders, :amount_cents, :integer, limit: 8
      change_column :accounts, :balance_cents, :integer, limit: 8
      change_column :transactions, :amount_cents, :integer, limit: 8
      change_column :transactions, :balance_before_cents, :integer, limit: 8
      change_column :transactions, :balance_after_cents, :integer, limit: 8

      remove_column :orders, :amount
      remove_column :accounts, :balance
      remove_column :transactions, :amount
      remove_column :transactions, :balance_before
      remove_column :transactions, :balance_after
    }
  end

  def down
    safety_assured {
      change_column :orders, :amount_cents, :integer
      change_column :accounts, :balance_cents, :integer
      change_column :transactions, :amount_cents, :integer
      change_column :transactions, :balance_before_cents, :integer
      change_column :transactions, :balance_after_cents, :integer

      add_column :orders, :amount, :decimal, precision: 15, scale: 2
      add_column :accounts, :balance, :decimal, precision: 15, scale: 2
      add_column :transactions, :amount, :decimal, precision: 15, scale: 2
      add_column :transactions, :balance_before, :decimal, precision: 15, scale: 2
      add_column :transactions, :balance_after, :decimal, precision: 15, scale: 2
    }
  end
end
