class AddStatusToBanks < ActiveRecord::Migration[8.1]
  def change
    change_table :banks, bulk: true do |t|
      t.string :status, default: 'healthy', null: false
      t.string :plaid_error_code
    end
  end
end
