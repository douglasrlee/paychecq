class AllocationEngine
  # Idempotently propose Allocation rows for one funding event — one per
  # expense on the schedule, created with funded_at: nil. Setting
  # processed_at signals "we've considered this event."
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

    funding_event.update!(processed_at: Time.current)
  end

  # Walk this user's pending allocations in due-date order and flip
  # funded_at when current available_balance can back them.
  def self.fund_pending_for(user)
    available = user.bank_accounts.sum(:available_balance)
    already_funded = Allocation.joins(:expense)
                               .where(expenses: { user_id: user.id })
                               .where.not(funded_at: nil)
                               .sum(:amount)

    pending = Allocation.joins(:expense)
                        .where(expenses: { user_id: user.id }, funded_at: nil)
                        .order('expenses.due_on ASC, expenses.created_at ASC')

    pending.find_each do |allocation|
      next unless available >= already_funded + allocation.amount

      allocation.update!(funded_at: Time.current)
      already_funded += allocation.amount
    end
  end

  # Look-ahead split: remaining-amount / paychecks-remaining-until-due.
  # Past-due falls to "this paycheck covers the rest" (clamped to 1).
  private_class_method def self.compute_proposed_amount(expense, schedule, as_of:)
    remaining = expense.amount - expense.allocations.sum(:amount)
    return 0 if remaining <= 0

    next_due = expense.next_due_on(after: as_of)
    paychecks_remaining = schedule.next_occurrences(count: 100, after: as_of)
                                  .count { |d| d <= next_due }
    paychecks_remaining = 1 if paychecks_remaining.zero?

    (remaining / paychecks_remaining).round(2)
  end
end
