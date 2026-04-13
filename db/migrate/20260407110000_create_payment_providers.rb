class CreatePaymentProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_providers do |t|
      t.string :type, null: false
      t.string :name, null: false
      t.integer :priority, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.jsonb :config, default: {}

      t.timestamps
    end

    add_index :payment_providers, :priority
    add_index :payment_providers, [:is_active, :priority]
    add_index :payment_providers, :name, unique: true
  end
end
