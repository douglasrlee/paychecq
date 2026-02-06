class RemoveCurrencyCodeFromTransactions < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :transactions, :currency_code, :string }
  end
end
