class AllocationEngine
  # Idempotently propose Allocation rows for one funding event — one per
  # expense and one per goal on the schedule, created with funded_at: nil.
  # Setting processed_at signals "we've considered this event."
  def self.propose_for(funding_event)
    return if funding_event.processed_at.present?

    schedule = funding_event.funding_schedule
    schedule.expenses.find_each do |expense|
      amount = compute_proposed_amount(expense, schedule, as_of: funding_event.occurs_on)
      next if amount <= 0

      Allocation.create_or_find_by!(funding_event: funding_event, expense: expense) do |a|
        a.amount = amount
      end
    end

    schedule.goals.find_each do |goal|
      amount = compute_proposed_amount(goal, schedule, as_of: funding_event.occurs_on)
      next if amount <= 0

      Allocation.create_or_find_by!(funding_event: funding_event, goal: goal) do |a|
        a.amount = amount
      end
    end

    funding_event.update!(processed_at: Time.current)
  end

  # Walk this user's pending allocations (expenses + goals) in due-date order
  # and flip funded_at when current available_balance can back them. Serialized
  # per-user with a row lock so concurrent runs can't double-fund off
  # the same already_funded baseline.
  def self.fund_pending_for(user)
    user.with_lock do
      available = user.bank_accounts.sum(:available_balance) || 0

      already_funded = Allocation.where(expense_id: user.expense_ids)
                                 .or(Allocation.where(goal_id: user.goal_ids))
                                 .where.not(funded_at: nil)
                                 .where('allocations.amount > allocations.spent_amount')
                                 .sum(Arel.sql('allocations.amount - allocations.spent_amount'))

      pending_allocations_for(user).each do |allocation|
        next unless available >= already_funded + allocation.amount

        allocation.update!(funded_at: Time.current)
        already_funded += allocation.amount
      end
    end
  end

  # Load pending expense + goal allocations sorted by due_on across both types.
  # Bounded in size per user so loading all into memory is fine.
  private_class_method def self.pending_allocations_for(user)
    pending_expense = Allocation.eager_load(:expense)
                                .where(expenses: { user_id: user.id }, funded_at: nil)
                                .order('expenses.due_on ASC, expenses.created_at ASC')
                                .to_a

    pending_goal = Allocation.eager_load(:goal)
                             .where(goals: { user_id: user.id }, funded_at: nil)
                             .order('goals.due_on ASC, goals.created_at ASC')
                             .to_a

    # Tie-break on the expense/goal's created_at (matching each per-type SQL
    # order above), not the allocation's, so same-due-date items keep a stable
    # funding priority.
    (pending_expense + pending_goal)
      .sort_by do |a|
        item = a.expense || a.goal
        [ item.due_on, item.created_at ]
      end
  end

  # Look-ahead split: remaining-amount / paychecks-remaining-until-due.
  # Works for both Expense and Goal since both expose the same interface
  # (amount, allocations, next_due_on).
  private_class_method def self.compute_proposed_amount(item, schedule, as_of:)
    active = item.allocations
                 .where('amount > spent_amount')
                 .sum(Arel.sql('amount - spent_amount'))
    remaining = item.amount - active
    return 0 if remaining <= 0

    next_due = item.next_due_on(after: as_of)
    paychecks_remaining = schedule.occurrence_count_between(after: as_of, through: next_due)
    paychecks_remaining = 1 if paychecks_remaining.zero?

    (remaining / paychecks_remaining).round(2)
  end
end
