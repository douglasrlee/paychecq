class AddPlaidFieldsToTransactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # rubocop:disable Rails/BulkChangeTable -- bulk: true is incompatible with algorithm: :concurrently
  def change
    add_column :transactions, :bank_account_id, :uuid
    add_column :transactions, :plaid_transaction_id, :string
    add_column :transactions, :date, :date
    add_column :transactions, :authorized_date, :date
    add_column :transactions, :merchant_name, :string
    add_column :transactions, :payment_channel, :string
    add_column :transactions, :personal_finance_category, :string
    add_column :transactions, :personal_finance_category_detailed, :string
    add_column :transactions, :logo_url, :string
    add_column :transactions, :merchant_entity_id, :string
    add_column :transactions, :currency_code, :string

    add_index :transactions, :bank_account_id, algorithm: :concurrently
    add_index :transactions, :plaid_transaction_id, unique: true, algorithm: :concurrently
    add_index :transactions, :date, algorithm: :concurrently

    add_foreign_key :transactions, :bank_accounts, validate: false
  end
  # rubocop:enable Rails/BulkChangeTable
end
