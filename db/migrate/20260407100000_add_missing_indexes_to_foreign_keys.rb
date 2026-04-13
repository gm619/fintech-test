class AddMissingIndexesToForeignKeys < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # orders.user_id and transactions.order_id already have indexes from foreign keys
    add_index :transactions, :order_id, algorithm: :concurrently, if_not_exists: true
    add_index :audit_logs, [ :user_id, :created_at ], algorithm: :concurrently, if_not_exists: true
  end
end
