class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :balance, null: false, default: 0.0, precision: 15, scale: 2
      t.timestamps
    end
  end
end
