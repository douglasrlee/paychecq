class AddTransactionCursorToBanks < ActiveRecord::Migration[8.1]
  def change
    add_column :banks, :transaction_cursor, :string
  end
end
