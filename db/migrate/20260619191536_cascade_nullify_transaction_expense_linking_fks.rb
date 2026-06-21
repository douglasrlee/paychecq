class CascadeNullifyTransactionExpenseLinkingFks < ActiveRecord::Migration[8.1]
  # Without these on_delete actions:
  #   * Deleting an expense that has linked transactions raises an FK
  #     violation. ExpensesController#destroy doesn't guard against it.
  #   * Plaid sync's destroy_all of removed-from-bank transactions raises
  #     an FK violation when an allocation references the doomed row via
  #     spent_by_transaction_id. (See TransactionSyncService.)
  #
  # SET NULL keeps the surviving rows intact and lets the deletes succeed.
  # On the Transaction side, a model-level before_destroy callback also
  # runs ExpenseLinker.unlink so the bucket and due_on are restored
  # cleanly — the FK action is the belt-and-suspenders DB-level safety net.
  #
  # Adding with validate: false to avoid the write-blocking validation;
  # the follow-up migration validates the constraints.
  def change
    remove_foreign_key :transactions, :expenses
    add_foreign_key :transactions, :expenses, on_delete: :nullify, validate: false

    remove_foreign_key :allocations, :transactions, column: :spent_by_transaction_id
    add_foreign_key :allocations, :transactions, column: :spent_by_transaction_id, on_delete: :nullify, validate: false
  end
end
