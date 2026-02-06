class ValidateBankAccountForeignKeyOnTransactions < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :transactions, :bank_accounts
  end
end
