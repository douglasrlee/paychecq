class ExpenseLinker
  # Link a transaction to an expense. Walks the expense's funded, untouched
  # allocations oldest-first and consumes them up to `transaction.amount`
  # (capped at bucket_balance — we never overspend). Most links are exact:
  # every touched allocation ends with spent_amount = amount. When the
  # transaction is less than the bucket, the walk stops mid-allocation,
  # leaving a residual that stays in the bucket. Either way, due_on
  # advances one cycle and the transaction remembers its expense.
  # If the transaction is already linked elsewhere, unlinks first (full
  # rollback of the prior expense) and then links to the new one.
  def self.link(transaction:, expense:)
    Transaction.transaction do
      unlink(transaction: transaction) if transaction.expense_id.present?

      # Lock the expense row so two concurrent links can't both walk and
      # update the same allocations. with_lock also wraps everything below
      # in the existing surrounding Transaction.transaction.
      expense.with_lock do
        remaining = transaction.amount
        spent_at = Time.current

        # The loop naturally stops when allocations are exhausted, so we
        # don't need to pre-cap remaining at bucket_balance — and capping
        # at bucket_balance would be wrong anyway, since bucket_balance
        # includes partial-spend residuals on already-touched allocations
        # that this walk can't reach.
        expense.allocations
               .where.not(funded_at: nil)
               .where(spent_by_transaction_id: nil)
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

        transaction.update!(expense: expense)
        expense.bump_due_forward!
      end
    end
  end

  # Full undo of a prior link: zero out every allocation touched by this
  # transaction (single-spender invariant means resetting spent_amount to
  # 0 always restores the original state), clear the FK, roll due_on back
  # one cycle.
  def self.unlink(transaction:)
    expense = transaction.expense
    return unless expense

    Transaction.transaction do
      Allocation.where(spent_by_transaction: transaction).find_each do |allocation|
        allocation.update!(spent_amount: 0, spent_at: nil, spent_by_transaction: nil)
      end

      transaction.update!(expense: nil)
      expense.bump_due_backward!
    end
  end
end
