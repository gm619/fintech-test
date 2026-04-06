class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, null: false, precision: 15, scale: 2
      t.string :status, null: false, default: 'created'
      t.timestamps
    end
    add_index :orders, :status
  end
end
