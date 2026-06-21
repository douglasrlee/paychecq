class ExpenseLinker
  # Link a transaction to an expense. Walks the expense's untouched funded
  # allocations oldest-first and consumes them up to `transaction.amount`.
  # Most links are exact: every touched allocation ends with
  # `spent_amount == amount`. When the transaction is smaller than the
  # bucket, the walk stops mid-allocation, leaving a residual. When the
  # transaction is larger than the bucket, the walk runs out of allocations
  # and the leftover transaction amount simply isn't accounted for here.
  # Either way, due_on advances one cycle and the transaction remembers
  # which expense it satisfied — plus the pre-link due_on, so unlink can
  # restore it exactly (round-trips around day-clamping months).
  # If the transaction is already linked elsewhere, unlinks first (full
  # rollback of the prior expense) and then links to the new one.
  def self.link(transaction:, expense:)
    Transaction.transaction do
      unlink(transaction: transaction) if transaction.expense_id.present?

      # Lock the expense row so two concurrent links can't both walk and
      # update the same allocations. with_lock also wraps everything below
      # in the existing surrounding Transaction.transaction.
      expense.with_lock do
        previous_due_on = expense.due_on
        remaining = transaction.amount
        spent_at = Time.current

        # Filter on `spent_amount: 0` to express "never touched" directly,
        # which keeps the single-spender invariant intact even if a row
        # ever ended up with a stale FK while still having no consumed
        # amount.
        expense.allocations
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

        transaction.update!(expense: expense, previous_due_on: previous_due_on)
        expense.bump_due_forward!
      end
    end
  end

  # Full undo of a prior link: zero out every allocation touched by this
  # transaction (single-spender invariant means resetting spent_amount to
  # 0 always restores the original state), clear the FK, and restore
  # due_on to the exact value it had at link time (using the previous_due_on
  # we stored on the transaction).
  def self.unlink(transaction:)
    expense = transaction.expense
    return unless expense

    Transaction.transaction do
      Allocation.where(spent_by_transaction: transaction).find_each do |allocation|
        allocation.update!(spent_amount: 0, spent_at: nil, spent_by_transaction: nil)
      end

      restored_due_on = transaction.previous_due_on
      transaction.update!(expense: nil, previous_due_on: nil)
      expense.update!(due_on: restored_due_on) if restored_due_on.present?
    end
  end
end
