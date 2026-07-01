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
      transaction.lock!
      goal.with_lock do
        spends = AllocationSpend.where(spent_by_transaction: transaction)
        allocation_ids = spends.pluck(:allocation_id)
        spends.delete_all

        remaining_by = AllocationSpend.where(allocation_id: allocation_ids)
                                      .group(:allocation_id)
                                      .sum(:amount)
        last_spent_at_by = AllocationSpend.where(allocation_id: allocation_ids)
                                          .group(:allocation_id)
                                          .maximum(:created_at)

        Allocation.where(id: allocation_ids).find_each do |allocation|
          allocation.update!(
            spent_amount: remaining_by[allocation.id] || 0,
            spent_at: last_spent_at_by[allocation.id]
          )
        end

        transaction.update!(goal: nil)
      end
    end
  end
end
