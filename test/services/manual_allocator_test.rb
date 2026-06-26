require 'test_helper'

class ManualAllocatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe) # $6,000 available across chase_checking + chase_savings
    @user.expenses.destroy_all
    @user.goals.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @expense  = @user.expenses.create!(name: 'Rent', amount: 1000, cadence: 'monthly', due_on: Date.new(2026, 2, 1), funding_schedule: @schedule)
  end

  test 'setting a balance from zero allocates and lowers free-to-spend' do
    result = ManualAllocator.set_balance(item: @expense, amount: 250)

    assert result.ok?
    assert_equal 250, @expense.reload.bucket_balance.to_f
    assert_equal 5750, @user.free_to_spend.to_f
    assert @expense.allocations.manual.first.funded_at.present?
  end

  test 'raising the balance only moves the difference' do
    ManualAllocator.set_balance(item: @expense, amount: 100)
    ManualAllocator.set_balance(item: @expense, amount: 400)

    assert_equal 1, @expense.allocations.manual.count
    assert_equal 400, @expense.reload.bucket_balance.to_f
    assert_equal 5600, @user.free_to_spend.to_f
  end

  test 'raising the balance beyond free-to-spend is rejected' do
    result = ManualAllocator.set_balance(item: @expense, amount: 6000.01)

    assert_not result.ok?
    assert_match(/free-to-spend/i, result.error)
    assert_equal 0, @expense.reload.bucket_balance.to_f
  end

  test 'a negative balance is rejected' do
    result = ManualAllocator.set_balance(item: @expense, amount: -5)

    assert_not result.ok?
  end

  test 'lowering the balance returns money to free-to-spend' do
    ManualAllocator.set_balance(item: @expense, amount: 300)

    ManualAllocator.set_balance(item: @expense, amount: 200)

    assert_equal 200, @expense.reload.bucket_balance.to_f
    assert_equal 5800, @user.free_to_spend.to_f
  end

  test 'setting the balance to zero clears the manual allocation' do
    ManualAllocator.set_balance(item: @expense, amount: 300)

    ManualAllocator.set_balance(item: @expense, amount: 0)

    assert_equal 0, @expense.allocations.manual.count
    assert_equal 0, @expense.reload.bucket_balance.to_f
  end

  test 'lowering the balance draws down auto-allocated paycheck money too' do
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    auto = Allocation.create!(funding_event: event, expense: @expense, amount: 50, funded_at: Time.current)
    assert_equal 50, @expense.bucket_balance.to_f

    ManualAllocator.set_balance(item: @expense, amount: 30)

    assert_equal 30, @expense.reload.bucket_balance.to_f
    assert_equal 30, auto.reload.amount.to_f, 'auto allocation reduced'
  end

  test 'lowering draws from the manual row before auto paycheck money' do
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    auto = Allocation.create!(funding_event: event, expense: @expense, amount: 50, funded_at: Time.current)
    ManualAllocator.set_balance(item: @expense, amount: 90) # +40 manual on top of the $50 auto

    ManualAllocator.set_balance(item: @expense, amount: 60) # remove $30

    assert_equal 50, auto.reload.amount.to_f, 'auto untouched while manual covers it'
    assert_equal 10, @expense.allocations.manual.first.amount.to_f
    assert_equal 60, @expense.reload.bucket_balance.to_f
  end

  test 'lowering never drops an allocation below what a transaction already spent' do
    ManualAllocator.set_balance(item: @expense, amount: 100)
    manual = @expense.allocations.manual.first
    txn = Transaction.create!(name: 'PARTIAL', amount: 40, bank_account: bank_accounts(:chase_checking))
    manual.update!(spent_amount: 40, spent_at: Time.current, spent_by_transaction: txn)
    assert_equal 60, @expense.bucket_balance.to_f # 100 - 40 spent

    ManualAllocator.set_balance(item: @expense, amount: 0)

    assert_equal 0, @expense.reload.bucket_balance.to_f
    assert_equal 40, manual.reload.amount.to_f, 'floored at the spent amount, row kept'
  end

  test 'fully allocating by hand leaves the engine nothing to propose' do
    soon = @user.expenses.create!(name: 'Trip', amount: 1000, cadence: 'monthly', due_on: Date.new(2026, 1, 29), funding_schedule: @schedule)
    ManualAllocator.set_balance(item: soon, amount: 1000)

    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))

    assert_no_difference -> { soon.allocations.where(funding_event: event).count } do
      AllocationEngine.propose_for(event)
    end
  end

  test 'works for goals too' do
    goal = @user.goals.create!(name: 'New laptop', amount: 2000, cadence: 'yearly', due_on: Date.new(2026, 12, 1), funding_schedule: @schedule)

    result = ManualAllocator.set_balance(item: goal, amount: 500)

    assert result.ok?
    assert_equal 500, goal.reload.bucket_balance.to_f
  end
end
