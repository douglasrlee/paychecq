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

  test 'link marks funded unspent allocations spent, sets goal, advances due_on' do
    assert_equal 7.99, @vacation.bucket_balance.to_f
    original_due_on = @vacation.due_on

    GoalLinker.link(transaction: @transaction, goal: @vacation)

    assert_equal 0, @vacation.reload.bucket_balance.to_f
    assert_equal @vacation, @transaction.reload.goal
    assert_equal Date.new(2026, 3, 14), @vacation.due_on
    assert_not_equal original_due_on, @vacation.due_on

    spent = @allocation.reload
    assert spent.spent_at.present?
    assert_equal @transaction, spent.spent_by_transaction
  end

  test 'link against an already goal-linked transaction unlinks the prior goal first' do
    other = @user.goals.create!(name: 'Other', amount: 50, cadence: 'monthly', due_on: Date.new(2026, 2, 20), funding_schedule: @schedule)
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    vacation_due_after_first_link = @vacation.reload.due_on
    other_due_before = other.due_on

    GoalLinker.link(transaction: @transaction, goal: other)

    @vacation.reload
    other.reload
    assert_equal other, @transaction.reload.goal
    assert_not_equal vacation_due_after_first_link, @vacation.due_on, 'vacation due_on should roll back'
    assert_not_equal other_due_before, other.due_on, 'other due_on should advance'
    assert_nil @allocation.reload.spent_at, 'vacation allocation should be unspent again'
  end

  test 'link unlinks a prior expense link before linking to the goal' do
    expense = @user.expenses.create!(name: 'Netflix', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    expense_allocation = Allocation.create!(funding_event: event, expense: expense, amount: 15.99, funded_at: Time.current)
    ExpenseLinker.link(transaction: @transaction, expense: expense)

    GoalLinker.link(transaction: @transaction, goal: @vacation)

    assert_nil @transaction.reload.expense, 'expense link removed'
    assert_equal @vacation, @transaction.goal
    assert_nil expense_allocation.reload.spent_at, 'expense allocation restored'
    assert_equal 15.99, expense.reload.bucket_balance.to_f
  end

  test 'unlink reverses everything' do
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    GoalLinker.unlink(transaction: @transaction)

    assert_nil @transaction.reload.goal
    assert_equal Date.new(2026, 2, 14), @vacation.reload.due_on
    assert_nil @allocation.reload.spent_at
    assert_nil @allocation.spent_by_transaction
    assert_equal 7.99, @vacation.bucket_balance.to_f
  end

  test 'link still flips FK and advances due_on when goal has no funded allocations' do
    empty = @user.goals.create!(name: 'Empty', amount: 10, cadence: 'monthly', due_on: Date.new(2026, 3, 1), funding_schedule: @schedule)

    assert_equal 0, empty.bucket_balance.to_f
    GoalLinker.link(transaction: @transaction, goal: empty)

    assert_equal empty, @transaction.reload.goal
    assert_equal Date.new(2026, 4, 1), empty.reload.due_on
  end

  test 'unlink is a no-op when the transaction has no goal' do
    assert_nothing_raised do
      GoalLinker.unlink(transaction: @transaction)
    end
    assert_nil @transaction.goal
  end

  test 'link/unlink round-trip preserves a Jan 31 due date through Feb clamping' do
    quirky = @user.goals.create!(name: 'Mortgage', amount: 100, cadence: 'monthly',
                                 due_on: Date.new(2026, 1, 31), funding_schedule: @schedule)
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: event, goal: quirky, amount: 100, funded_at: Time.current)
    txn = Transaction.create!(name: 'MORTGAGE', amount: 100, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: txn, goal: quirky)
    assert_equal Date.new(2026, 2, 28), quirky.reload.due_on, 'forward clamps Feb to 28'
    assert_equal Date.new(2026, 1, 31), txn.reload.previous_due_on

    GoalLinker.unlink(transaction: txn)

    assert_equal Date.new(2026, 1, 31), quirky.reload.due_on, 'unlink restores the original 31st'
    assert_nil txn.reload.previous_due_on
  end

  test 'destroying a linked transaction unlinks it first so the bucket and due_on restore cleanly' do
    GoalLinker.link(transaction: @transaction, goal: @vacation)
    assert_equal 0, @vacation.reload.bucket_balance.to_f
    advanced_due = @vacation.due_on

    @transaction.destroy!

    assert_equal 7.99, @vacation.reload.bucket_balance.to_f, 'bucket restored'
    assert_not_equal advanced_due, @vacation.due_on, 'due_on rolled back'
    assert_nil @allocation.reload.spent_at
    assert_nil @allocation.spent_by_transaction_id
    assert_equal 0, @allocation.spent_amount.to_f
  end

  test 'partial link: transaction smaller than bucket leaves the residual in the bucket' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)
    assert_equal 15.99, @vacation.bucket_balance.to_f

    partial = Transaction.create!(name: 'PARTIAL', amount: 5.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)

    assert_equal 10.99, @vacation.reload.bucket_balance.to_f
    assert_equal @vacation, partial.reload.goal
    assert_equal Date.new(2026, 3, 14), @vacation.due_on, 'due_on rolls forward even on partial'
  end

  test 'partial link spends oldest allocation fully and the next one partially' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)

    first = @allocation.reload
    second.reload

    assert_equal 7.99, first.spent_amount.to_f, 'oldest allocation fully consumed'
    assert_equal first.amount, first.spent_amount, 'oldest fully spent'
    assert_equal partial, first.spent_by_transaction

    assert_equal 2.01, second.spent_amount.to_f, 'next allocation takes the remainder'
    assert second.amount > second.spent_amount, 'next allocation has residual'
    assert_equal partial, second.spent_by_transaction

    assert_equal 5.99, @vacation.reload.bucket_balance.to_f, '15.99 - 10.00'
  end

  test 'unlink restores a partial link cleanly' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)
    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: partial, goal: @vacation)
    GoalLinker.unlink(transaction: partial)

    assert_nil partial.reload.goal
    assert_equal Date.new(2026, 2, 14), @vacation.reload.due_on, 'due_on rolls back'
    assert_equal 15.99, @vacation.bucket_balance.to_f, 'bucket fully restored'

    [ @allocation, second ].each do |allocation|
      allocation.reload
      assert_equal 0, allocation.spent_amount.to_f
      assert_nil allocation.spent_at
      assert_nil allocation.spent_by_transaction
    end
  end

  test 'link caps consumption at bucket_balance when transaction exceeds it' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)

    overpay = Transaction.create!(name: 'OVERPAY', amount: 99.00, bank_account: bank_accounts(:chase_checking))

    GoalLinker.link(transaction: overpay, goal: @vacation)

    assert_equal 0, @vacation.reload.bucket_balance.to_f, 'bucket fully drained, never negative'
    assert_equal @vacation, overpay.reload.goal
  end

  test 'link skips allocations already spent by a prior transaction' do
    first_partial = Transaction.create!(name: 'PRIOR', amount: 3.00, bank_account: bank_accounts(:chase_checking))
    GoalLinker.link(transaction: first_partial, goal: @vacation)

    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, goal: @vacation, amount: 8.00, funded_at: Time.current)
    assert_equal 12.99, @vacation.reload.bucket_balance.to_f

    next_txn = Transaction.create!(name: 'NEXT', amount: 8.00, bank_account: bank_accounts(:chase_checking))
    GoalLinker.link(transaction: next_txn, goal: @vacation)

    assert_equal first_partial, @allocation.reload.spent_by_transaction
    assert_equal 3.00, @allocation.spent_amount.to_f

    second.reload
    assert_equal next_txn, second.spent_by_transaction
    assert_equal 8.00, second.spent_amount.to_f

    assert_equal 4.99, @vacation.bucket_balance.to_f
  end
end
