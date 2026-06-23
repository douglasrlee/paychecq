class GoalLinker
  # Mirror of ExpenseLinker for goals. Walks the goal's untouched funded
  # allocations oldest-first and consumes them up to `transaction.amount`.
  # If the transaction is already linked to an expense, unlinks that first.
  def self.link(transaction:, goal:)
    Transaction.transaction do
      # Lock the transaction row first so concurrent goal/expense link
      # requests serialize per-transaction. Without this two requests can each
      # see the other FK blank and commit with both expense_id and goal_id set.
      transaction.lock!

      ExpenseLinker.unlink(transaction: transaction) if transaction.expense_id.present?
      unlink(transaction: transaction) if transaction.goal_id.present?

      goal.with_lock do
        previous_due_on = goal.due_on
        remaining = transaction.amount
        spent_at = Time.current

        goal.allocations
            .where.not(funded_at: nil)
            .where(spent_amount: 0)
            .order(:funded_at, :created_at)
            .lock
            .each do |allocation|
          break if remaining <= 0

          consume = [ remaining, allocation.amount ].min
          allocation.update!(
            spent_amount: consume,
            spent_at: spent_at,
            spent_by_transaction: transaction
          )
          remaining -= consume
        end

        transaction.update!(goal: goal, previous_due_on: previous_due_on)
        goal.bump_due_forward!
      end
    end
  end

  def self.unlink(transaction:)
    goal = transaction.goal
    return unless goal

    Transaction.transaction do
      Allocation.where(spent_by_transaction: transaction).find_each do |allocation|
        allocation.update!(spent_amount: 0, spent_at: nil, spent_by_transaction: nil)
      end

      restored_due_on = transaction.previous_due_on
      transaction.update!(goal: nil, previous_due_on: nil)
      goal.update!(due_on: restored_due_on) if restored_due_on.present?
    end
  end
end
