class GoalLinker
  # Mirror of ExpenseLinker for goals. Draws the transaction's amount down from
  # the goal's funded allocations oldest-first, recording each draw as an
  # AllocationSpend so a bucket can be shared by several transactions. Due dates
  # are calendar-driven, so linking never touches due_on. If the transaction is
  # already linked to an expense, unlinks that first.
  def self.link(transaction:, goal:)
    Transaction.transaction do
      # Lock the transaction row first so concurrent goal/expense link
      # requests serialize per-transaction. Without this two requests can each
      # see the other FK blank and commit with both expense_id and goal_id set.
      transaction.lock!

      ExpenseLinker.unlink(transaction: transaction) if transaction.expense_id.present?
      unlink(transaction: transaction) if transaction.goal_id.present?

      goal.with_lock do
        remaining = transaction.amount
        spent_at = Time.current

        goal.allocations
            .where.not(funded_at: nil)
            .where('amount > spent_amount')
            .order(:funded_at, :created_at)
            .lock
            .each do |allocation|
          break if remaining <= 0

          available = allocation.amount - allocation.spent_amount
          consume = [ remaining, available ].min
          next if consume <= 0

          AllocationSpend.create!(allocation: allocation, spent_by_transaction: transaction, amount: consume)
          allocation.update!(spent_amount: allocation.spent_amount + consume, spent_at: spent_at)
          remaining -= consume
        end

        transaction.update!(goal: goal)
      end
    end
  end

  def self.unlink(transaction:)
    goal = transaction.goal
    return unless goal

    Transaction.transaction do
      goal.with_lock do
        AllocationSpend.where(spent_by_transaction: transaction).includes(:allocation).find_each do |spend|
          allocation = spend.allocation
          spend.destroy!
          remaining_spent = AllocationSpend.where(allocation: allocation).sum(:amount)
          allocation.update!(
            spent_amount: remaining_spent,
            spent_at: (remaining_spent.positive? ? allocation.spent_at : nil)
          )
        end

        transaction.update!(goal: nil)
      end
    end
  end
end
