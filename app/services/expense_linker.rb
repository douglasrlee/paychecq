class ExpenseLinker
  # Link a transaction to an expense. Marks the expense's funded, unspent
  # allocations as spent by this transaction (bucket -> 0), sets
  # transaction.expense_id, and advances the expense's due_on one cycle.
  # If the transaction is already linked elsewhere, unlinks first (full
  # rollback of the prior expense) and then links to the new one.
  def self.link(transaction:, expense:)
    Transaction.transaction do
      unlink(transaction: transaction) if transaction.expense_id.present?

      expense.allocations.where.not(funded_at: nil).unspent.find_each do |allocation|
        allocation.update!(spent_at: Time.current, spent_by_transaction: transaction)
      end

      transaction.update!(expense: expense)
      expense.bump_due_forward!
    end
  end

  # Full undo of a prior link: unspend the exact allocations this
  # transaction spent, clear the FK, roll the expense's due_on back one
  # cycle.
  def self.unlink(transaction:)
    expense = transaction.expense
    return unless expense

    Transaction.transaction do
      Allocation.where(spent_by_transaction: transaction).find_each do |allocation|
        allocation.update!(spent_at: nil, spent_by_transaction: nil)
      end

      transaction.update!(expense: nil)
      expense.bump_due_backward!
    end
  end
end
