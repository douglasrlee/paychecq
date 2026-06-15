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

  private

  def create_expense(name:, amount:, due_on:)
    @user.expenses.create!(name: name, amount: amount, cadence: 'monthly', due_on: due_on, funding_schedule: @schedule)
  end
end
