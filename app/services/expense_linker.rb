class ExpenseLinker
  # Link a transaction to an expense and draw the transaction's amount down
  # from the bucket. Walks the expense's funded allocations oldest-first and
  # consumes each one's remaining headroom (amount - spent_amount) up to
  # `transaction.amount`, recording each draw as an AllocationSpend row. A
  # bucket can be shared by several transactions — an expense paid by multiple
  # charges draws each one down in turn until the bucket is empty; any leftover
  # transaction amount beyond the bucket simply isn't accounted for here.
  #
  # Due dates are calendar-driven and independent of linking, so linking never
  # touches due_on. If the transaction is already linked elsewhere, unlinks
  # first (full rollback of the prior bucket) and then links here.
  def self.link(transaction:, expense:)
    Transaction.transaction do
      # Lock the transaction row first so concurrent expense/goal link
      # requests serialize per-transaction. Without this two requests can each
      # see the other FK blank and commit with both expense_id and goal_id set.
      transaction.lock!

      GoalLinker.unlink(transaction: transaction) if transaction.goal_id.present?
      unlink(transaction: transaction) if transaction.expense_id.present?

      # Lock the expense row so two concurrent links can't both walk and
      # update the same allocations. with_lock also wraps everything below
      # in the existing surrounding Transaction.transaction.
      expense.with_lock do
        remaining = transaction.amount
        spent_at = Time.current

        expense.allocations
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

        transaction.update!(expense: expense)
      end
    end
  end

  # Undo this transaction's draws: delete its AllocationSpend rows and recompute
  # each touched allocation's spent_amount from whatever spends remain (other
  # transactions may still be drawing on the same allocation). Clears the FK.
  def self.unlink(transaction:)
    expense = transaction.expense
    return unless expense

    Transaction.transaction do
      transaction.lock!
      expense.with_lock do
        spends = AllocationSpend.where(spent_by_transaction: transaction)
        allocation_ids = spends.pluck(:allocation_id)
        spends.delete_all

        remaining_by = AllocationSpend.where(allocation_id: allocation_ids)
                                      .group(:allocation_id)
                                      .sum(:amount)

        Allocation.where(id: allocation_ids).find_each do |allocation|
          remaining = remaining_by[allocation.id] || 0
          allocation.update!(
            spent_amount: remaining,
            spent_at: remaining.positive? ? allocation.spent_at : nil
          )
        end

        transaction.update!(expense: nil)
      end
    end
  end
end
