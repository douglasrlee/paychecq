class AddTransactionExpenseLinking < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # rubocop:disable Rails/BulkChangeTable -- bulk: true is incompatible with algorithm: :concurrently
  def change
    add_column :transactions, :expense_id, :uuid
    add_column :allocations, :spent_at, :datetime
    add_column :allocations, :spent_by_transaction_id, :uuid

    add_index :transactions, :expense_id, algorithm: :concurrently
    add_index :allocations, :spent_by_transaction_id, algorithm: :concurrently

    add_foreign_key :transactions, :expenses, validate: false
    add_foreign_key :allocations, :transactions, column: :spent_by_transaction_id, validate: false
  end
  # rubocop:enable Rails/BulkChangeTable
end
