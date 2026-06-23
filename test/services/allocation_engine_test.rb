require 'test_helper'

class AllocationEngineTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe)
    # Wipe fixtures so each test starts with a clean allocation state for this user.
    @user.expenses.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
  end

  test 'propose_for creates one allocation per expense, all pending' do
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29)) # 3 paychecks: Jan 1, 15, 29
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_difference 'Allocation.count', 1 do
      AllocationEngine.propose_for(event)
    end

    allocation = event.allocations.find_by(expense: expense)
    assert_in_delta 5.33, allocation.amount.to_f, 0.01 # 15.99 / 3
    assert_nil allocation.funded_at
    assert event.reload.processed_at.present?
  end

  test 'propose_for is idempotent' do
    create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    AllocationEngine.propose_for(event)

    assert_no_difference 'Allocation.count' do
      AllocationEngine.propose_for(event)
    end
  end

  test 'propose_for skips fully-funded expenses' do
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    earlier_event = @schedule.funding_events.create!(occurs_on: Date.new(2025, 12, 18))
    Allocation.create!(funding_event: earlier_event, expense: expense, amount: 15.99, funded_at: Time.current)

    new_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_no_difference 'Allocation.count' do
      AllocationEngine.propose_for(new_event)
    end
  end

  test 'propose_for past-due expense allocates full remaining' do
    expense = create_expense(name: 'Bill', amount: 100, due_on: Date.new(2025, 12, 1)) # past due
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    AllocationEngine.propose_for(event)

    allocation = event.allocations.find_by(expense: expense)
    assert_equal 100.00, allocation.amount.to_f
  end

  test 'fund_pending_for funds everything when balance covers' do
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    AllocationEngine.propose_for(event)

    AllocationEngine.fund_pending_for(@user)

    assert event.allocations.find_by(expense: expense).funded_at.present?
  end

  test 'fund_pending_for funds in due-date order when balance is partial' do
    # Urgent allocation will be $30 (60 / 2 paychecks), Later will be $20 (80 / 4).
    # Total available $30 covers urgent only.
    bank_accounts(:chase_checking).update!(available_balance: 30)
    bank_accounts(:chase_savings).update!(available_balance: 0)

    urgent = create_expense(name: 'Urgent', amount: 60, due_on: Date.new(2026, 1, 15))
    later  = create_expense(name: 'Later',  amount: 80, due_on: Date.new(2026, 2, 12))

    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    AllocationEngine.propose_for(event)

    AllocationEngine.fund_pending_for(@user)

    urgent_alloc = event.allocations.find_by(expense: urgent)
    later_alloc  = event.allocations.find_by(expense: later)
    assert urgent_alloc.funded_at.present?, 'urgent expense should be funded first'
    assert_nil later_alloc.funded_at, 'later expense should remain pending when balance runs out'
  end

  test 'fund_pending_for picks up previously-pending allocations on a later run' do
    # Allocation will be ~$5.33; start with $4 total available so it doesn't fit.
    @user.bank_accounts.update_all(available_balance: 2) # rubocop:disable Rails/SkipsModelValidations
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    AllocationEngine.propose_for(event)
    AllocationEngine.fund_pending_for(@user)
    assert_nil event.allocations.find_by(expense: expense).funded_at

    @user.bank_accounts.update_all(available_balance: 100) # rubocop:disable Rails/SkipsModelValidations

    AllocationEngine.fund_pending_for(@user)

    assert event.allocations.find_by(expense: expense).reload.funded_at.present?
  end

  test 'propose_for refunds the next cycle after a previous cycle was spent' do
    # Cycle 1: fully fund $15.99, then mark it spent (simulating a link).
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    cycle1_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    spent = Allocation.create!(funding_event: cycle1_event, expense: expense, amount: 15.99,
                               funded_at: Time.current, spent_at: Time.current, spent_amount: 15.99)
    assert_equal 15.99, spent.spent_amount.to_f

    # Cycle 2: advance due_on, materialize a new paycheck event, propose.
    expense.update!(due_on: Date.new(2026, 2, 26)) # advanced
    cycle2_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 29))

    assert_difference 'Allocation.count', 1 do
      AllocationEngine.propose_for(cycle2_event)
    end

    cycle2_allocation = cycle2_event.allocations.find_by(expense: expense)
    # Cycle 2 has 3 paychecks remaining (Jan 29, Feb 12, Feb 26): 15.99 / 3 = 5.33
    assert_in_delta 5.33, cycle2_allocation.amount.to_f, 0.01
  end

  test 'fund_pending_for ignores spent allocations when computing the already-funded headroom' do
    # Without this fix the engine treats spent allocations as still earmarked
    # against the bank balance, so eventually it would refuse to fund any
    # new pending allocations even though the money is genuinely available.
    bank_accounts(:chase_checking).update!(available_balance: 20)
    bank_accounts(:chase_savings).update!(available_balance: 0)

    expense = create_expense(name: 'Recurring', amount: 15, due_on: Date.new(2026, 2, 12))
    spent_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: spent_event, expense: expense, amount: 15,
                       funded_at: Time.current, spent_at: Time.current, spent_amount: 15)

    new_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    new_allocation = Allocation.create!(funding_event: new_event, expense: expense, amount: 15, funded_at: nil)

    AllocationEngine.fund_pending_for(@user)

    assert new_allocation.reload.funded_at.present?, 'new allocation should fund since spent ones no longer eat the headroom'
  end

  test 'propose_for reduces next-cycle proposal by a partial-spend residual' do
    # Cycle 1: $10 allocation funded, only $6.33 spent (partial). Residual $3.67 sits in the bucket.
    expense = create_expense(name: 'Test', amount: 10, due_on: Date.new(2026, 1, 29))
    cycle1_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: cycle1_event, expense: expense, amount: 10,
                       funded_at: Time.current, spent_at: Time.current, spent_amount: 6.33)
    assert_equal 3.67, expense.bucket_balance.to_f

    expense.update!(due_on: Date.new(2026, 2, 26))
    cycle2_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 29))

    AllocationEngine.propose_for(cycle2_event)

    cycle2_allocation = cycle2_event.allocations.find_by(expense: expense)
    # Only (10 - 3.67) = $6.33 still needs to be allocated, split over 3 paychecks (Jan 29, Feb 12, Feb 26).
    assert_in_delta 2.11, cycle2_allocation.amount.to_f, 0.01 # 6.33 / 3
  end

  test 'propose_for creates one allocation per goal, all pending' do
    goal = create_goal(name: 'Vacation', amount: 15.99, due_on: Date.new(2026, 1, 29)) # 3 paychecks: Jan 1, 15, 29
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_difference 'Allocation.count', 1 do
      AllocationEngine.propose_for(event)
    end

    allocation = event.allocations.find_by(goal: goal)
    assert_in_delta 5.33, allocation.amount.to_f, 0.01 # 15.99 / 3
    assert_nil allocation.funded_at
    assert event.reload.processed_at.present?
  end

  test 'propose_for proposes for expenses and goals on the same schedule' do
    expense = create_expense(name: 'Netflix', amount: 15.99, due_on: Date.new(2026, 1, 29))
    goal = create_goal(name: 'Vacation', amount: 1200, due_on: Date.new(2026, 12, 1))
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_difference 'Allocation.count', 2 do
      AllocationEngine.propose_for(event)
    end

    assert event.allocations.find_by(expense: expense).present?
    assert event.allocations.find_by(goal: goal).present?
  end

  test 'propose_for skips fully-funded goals' do
    goal = create_goal(name: 'Vacation', amount: 50, due_on: Date.new(2026, 12, 1))
    earlier_event = @schedule.funding_events.create!(occurs_on: Date.new(2025, 12, 18))
    Allocation.create!(funding_event: earlier_event, goal: goal, amount: 50, funded_at: Time.current)

    new_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_no_difference 'Allocation.count' do
      AllocationEngine.propose_for(new_event)
    end
  end

  test 'fund_pending_for breaks due-date ties by the item created_at, not the allocation created_at' do
    bank_accounts(:chase_checking).update!(available_balance: 50)
    bank_accounts(:chase_savings).update!(available_balance: 0)

    # Goal is created before the expense (earlier item created_at), but
    # propose_for builds the expense allocation first — so the allocation
    # created_at order is the opposite of the item created_at order. Both
    # share a due date, so the tie-break decides who funds first.
    goal = create_goal(name: 'Goal', amount: 50, due_on: Date.new(2026, 1, 1))
    expense = create_expense(name: 'Expense', amount: 50, due_on: Date.new(2026, 1, 1))
    assert goal.created_at < expense.created_at, 'goal item should be created before the expense item'

    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    AllocationEngine.propose_for(event)

    goal_alloc = event.allocations.find_by(goal: goal)
    expense_alloc = event.allocations.find_by(expense: expense)
    assert goal_alloc.created_at > expense_alloc.created_at, 'expense allocation should be created first'

    AllocationEngine.fund_pending_for(@user)

    assert goal_alloc.reload.funded_at.present?, 'earlier-created goal should fund first on a due-date tie'
    assert_nil expense_alloc.reload.funded_at, 'later-created expense waits when the balance covers only one'
  end

  test 'fund_pending_for funds a goal allocation when balance covers' do
    goal = create_goal(name: 'Vacation', amount: 15.99, due_on: Date.new(2026, 1, 29))
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    AllocationEngine.propose_for(event)

    AllocationEngine.fund_pending_for(@user)

    assert event.allocations.find_by(goal: goal).funded_at.present?
  end

  private

  def create_expense(name:, amount:, due_on:)
    @user.expenses.create!(name: name, amount: amount, cadence: 'monthly', due_on: due_on, funding_schedule: @schedule)
  end

  def create_goal(name:, amount:, due_on:)
    @user.goals.create!(name: name, amount: amount, cadence: 'monthly', due_on: due_on, funding_schedule: @schedule)
  end
end
