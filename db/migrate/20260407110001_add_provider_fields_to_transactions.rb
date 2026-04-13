class AddProviderFieldsToTransactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :transactions, :provider_name, :string
    add_column :transactions, :external_transaction_id, :string
    add_column :transactions, :provider_status, :string
    add_column :transactions, :provider_response, :jsonb, default: {}

    add_index :transactions, :provider_name, algorithm: :concurrently
    add_index :transactions, :external_transaction_id, algorithm: :concurrently
  end
end
