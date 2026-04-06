class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.decimal :amount, null: false, precision: 15, scale: 2
      t.string :operation_type, null: false  # 'debit' или 'credit'
      t.decimal :balance_before, null: false, precision: 15, scale: 2
      t.decimal :balance_after, null: false, precision: 15, scale: 2
      t.string :description
      t.timestamps
    end
    add_index :transactions, [ :account_id, :created_at ]
    #add_index :transactions, :order_id
  end
end
