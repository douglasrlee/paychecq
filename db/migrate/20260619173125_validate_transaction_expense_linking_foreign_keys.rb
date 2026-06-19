class ValidateTransactionExpenseLinkingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :transactions, :expenses
    validate_foreign_key :allocations, :transactions, column: :spent_by_transaction_id
  end
end
