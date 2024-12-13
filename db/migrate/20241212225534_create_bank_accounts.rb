# frozen_string_literal: true

class CreateBankAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :bank_accounts, id: :uuid do |t|
      t.belongs_to :user, null: false, foreign_key: true, type: :uuid
      t.string :name
      t.timestamps
    end
  end
end
