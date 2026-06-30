require 'test_helper'

class GoalLinkerTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe)
    @user.expenses.destroy_all
    @user.goals.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @vacation = @user.goals.create!(name: 'Vacation', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    @transaction = Transaction.create!(name: 'HOTEL', amount: 15.99, bank_account: bank_accounts(:chase_checking))

    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    @allocation = Allocation.create!(funding_event: event, goal: @vacation, amount: 7.99, funded_at: Time.current)
  end

  test 'link draws the transaction down from the bucket and sets the goal' do
    assert_equal 7.99, @vacation.bucket_balance.to_f
    original_due_on = @vacation.due_on

    GoalLinker.link(transaction: @transaction, goal: @vacation)

    assert_equal 0, @vacation.reload.bucket_balance.to_f
    assert_equal @vacation, @transaction.reload.goal
    assert_equal original_due_on, @vacation.due_on, 'due dates are calendar-driven; linking never moves them'

    spent = @allocation.reload
    assert_equal 7.99, spent.spent_amount.to_f
    assert spent.spent_at.present?
    assert_equal 1, AllocationSpend.where(spent_by_transaction: @transaction).count
  end

  test 'link against an already goal-linked transaction unlinks the prior goal first' do
    other = @user.goals.create!(name: 'Other', amount: 50, cadence: 'monthly', due_on: Date.new(2026, 2, 20), funding_schedule: @schedule)
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    GoalLinker.link(transaction: @transaction, goal: other)

    assert_equal other, @transaction.reload.goal
    assert_equal 7.99, @vacation.reload.bucket_balance.to_f, 'vacation bucket restored'
    assert_equal 0, @allocation.reload.spent_amount.to_f, 'vacation allocation unspent again'
  end

  test 'link unlinks a prior expense link before linking to the goal' do
    expense = @user.expenses.create!(name: 'Netflix', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    expense_allocation = Allocation.create!(funding_event: event, expense: expense, amount: 15.99, funded_at: Time.current)
    ExpenseLinker.link(transaction: @transaction, expense: expense)

    GoalLinker.link(transaction: @transaction, goal: @vacation)

    assert_nil @transaction.reload.expense, 'expense link removed'
    assert_equal @vacation, @transaction.goal
    assert_equal 0, expense_allocation.reload.spent_amount.to_f, 'expense allocation restored'
    assert_equal 15.99, expense.reload.bucket_balance.to_f
  end

  test 'unlink reverses everything' do
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    GoalLinker.unlink(transaction: @transaction)

    assert_nil @transaction.reload.goal
    assert_equal 7.99, @vacation.reload.bucket_balance.to_f
    assert_equal 0, @allocation.reload.spent_amount.to_f
    assert_nil @allocation.spent_at
    assert_equal 0, AllocationSpend.where(spent_by_transaction: @transaction).count
  end

  test 'link still flips the FK when the goal has no funded allocations' do
    empty = @user.goals.create!(name: 'Empty', amount: 10, cadence: 'monthly', due_on: Date.new(2026, 3, 1), funding_schedule: @schedule)

    assert_equal 0, empty.bucket_balance.to_f
    GoalLinker.link(transaction: @transaction, goal: empty)

    assert_equal empty, @transaction.reload.goal
    assert_equal 0, empty.reload.bucket_balance.to_f
  end

  test 'unlink is a no-op when the transaction has no goal' do
    assert_nothing_raised do
      GoalLinker.unlink(transaction: @transaction)
    end
    assert_nil @transaction.goal
  end

  test 'destroying a linked transaction unlinks it first so the bucket restores cleanly' do
    GoalLinker.link(transaction: @transaction, goal: @vacation)
    assert_equal 0, @vacation.reload.bucket_balance.to_f

    @transaction.destroy!

    assert_equal 7.99, @vacation.reload.bucket_balance.to_f, 'bucket restored'
    assert_equal 0, @allocation.reload.spent_amount.to_f
    assert_nil @allocation.spent_at
  end

  test 'partial link: transaction smaller than the bucket leaves the residual in the bucket' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)
    assert_equal 15.99, @vacation.bucket_balance.to_f

    partial = Transaction.create!(name: 'PARTIAL', amount: 5.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)

    assert_equal 10.99, @vacation.reload.bucket_balance.to_f
    assert_equal @vacation, partial.reload.goal
  end

  test 'partial link spends the oldest allocation fully and the next one partially' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)

    assert_equal 7.99, @allocation.reload.spent_amount.to_f, 'oldest allocation fully consumed'
    assert_equal 2.01, second.reload.spent_amount.to_f, 'next allocation takes the remainder'
    assert_equal 5.99, @vacation.reload.bucket_balance.to_f, '15.99 - 10.00'
    assert_equal 2, AllocationSpend.where(spent_by_transaction: partial).count
  end

  test 'unlink restores a partial link cleanly' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)
    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)
    GoalLinker.unlink(transaction: partial)

    assert_nil partial.reload.goal
    assert_equal 15.99, @vacation.reload.bucket_balance.to_f, 'bucket fully restored'

    [ @allocation, second ].each do |allocation|
      allocation.reload
      assert_equal 0, allocation.spent_amount.to_f
      assert_nil allocation.spent_at
    end
  end

  test 'link caps consumption at bucket_balance when the transaction exceeds it' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    overpay = Transaction.create!(name: 'OVERPAY', amount: 99.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: overpay, goal: @vacation)

    assert_equal 0, @vacation.reload.bucket_balance.to_f, 'bucket fully drained, never negative'
    assert_equal @vacation, overpay.reload.goal
  end

  test 'several transactions share one goal bucket (shared draw-down)' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    charge_a = Transaction.create!(name: 'CHARGE A', amount: 6.00, bank_account: bank_accounts(:chase_checking))
    charge_b = Transaction.create!(name: 'CHARGE B', amount: 9.99, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: charge_a, goal: @vacation)
    GoalLinker.link(transaction: charge_b, goal: @vacation)

    assert_equal @vacation, charge_a.reload.goal
    assert_equal @vacation, charge_b.reload.goal
    assert_equal 0, @vacation.reload.bucket_balance.to_f
    assert_equal 7.99, @allocation.reload.spent_amount.to_f
    assert_equal 8.00, second.reload.spent_amount.to_f
    assert_equal 2, AllocationSpend.where(allocation: @allocation).count, 'one allocation spent by two transactions'
  end

  test 'unlinking one of several shared transactions returns only its share' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    charge_a = Transaction.create!(name: 'CHARGE A', amount: 6.00, bank_account: bank_accounts(:chase_checking))
    charge_b = Transaction.create!(name: 'CHARGE B', amount: 9.99, bank_account: bank_accounts(:chase_checking))
    GoalLinker.link(transaction: charge_a, goal: @vacation)
    GoalLinker.link(transaction: charge_b, goal: @vacation)

    GoalLinker.unlink(transaction: charge_a)

    assert_nil charge_a.reload.goal
    assert_equal @vacation, charge_b.reload.goal, 'the other charge stays linked'
    assert_equal 6.00, @vacation.reload.bucket_balance.to_f
    assert_equal 1.99, @allocation.reload.spent_amount.to_f
    assert_equal 8.00, second.reload.spent_amount.to_f
  end
end
