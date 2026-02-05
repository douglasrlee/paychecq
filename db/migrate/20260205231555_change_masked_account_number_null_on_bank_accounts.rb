class ChangeMaskedAccountNumberNullOnBankAccounts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bank_accounts, :masked_account_number, true
  end
end
