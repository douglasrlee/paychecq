class AddStatusToBanks < ActiveRecord::Migration[8.1]
  def change
    add_column :banks, :status, :string, default: 'healthy', null: false
    add_column :banks, :plaid_error_code, :string
  end
end
