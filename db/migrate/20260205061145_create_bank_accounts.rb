class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts, id: :uuid do |table|
      table.string :name, null: false
      table.string :official_name
      table.string :masked_account_number, null: false
      table.string :account_type, null: false
      table.string :account_subtype
      table.decimal :available_balance, precision: 10, scale: 2
      table.decimal :current_balance, precision: 10, scale: 2
      table.datetime :last_synced_at, null: false

      table.string :plaid_account_id, null: false

      table.timestamps

      table.references :bank, null: false, foreign_key: true, type: :uuid

      table.index :plaid_account_id, unique: true
    end
  end
end
