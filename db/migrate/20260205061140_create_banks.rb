class CreateBanks < ActiveRecord::Migration[8.1]
  def change
    create_table :banks, id: :uuid do |table|
      table.string :name, null: false

      table.string :plaid_item_id, null: false
      table.string :plaid_access_token, null: false
      table.string :plaid_institution_id, null: false
      table.string :plaid_institution_name, null: false

      table.timestamps

      table.references :user, null: false, foreign_key: true, type: :uuid

      table.index :plaid_item_id, unique: true
    end
  end
end
