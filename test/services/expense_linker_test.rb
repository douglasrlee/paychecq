require 'test_helper'

class ExpenseLinkerTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe)
    @user.expenses.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @netflix  = @user.expenses.create!(name: 'Netflix', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    @transaction = Transaction.create!(name: 'NETFLIX.COM', amount: 15.99, bank_account: bank_accounts(:chase_checking))

    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    @allocation = Allocation.create!(funding_event: event, expense: @netflix, amount: 7.99, funded_at: Time.current)
  end

  test 'link marks funded unspent allocations spent, sets expense, advances due_on' do
    assert_equal 7.99, @netflix.bucket_balance.to_f
    original_due_on = @netflix.due_on

    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    assert_equal 0, @netflix.reload.bucket_balance.to_f
    assert_equal @netflix, @transaction.reload.expense
    assert_equal Date.new(2026, 3, 14), @netflix.due_on
    assert_not_equal original_due_on, @netflix.due_on

    spent = @allocation.reload
    assert spent.spent_at.present?
    assert_equal @transaction, spent.spent_by_transaction
  end

  test 'link against an already-linked transaction unlinks the prior expense first' do
    other = @user.expenses.create!(name: 'Other', amount: 50, cadence: 'monthly', due_on: Date.new(2026, 2, 20), funding_schedule: @schedule)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    netflix_due_after_first_link = @netflix.reload.due_on
    other_due_before = other.due_on

    ExpenseLinker.link(transaction: @transaction, expense: other)

    @netflix.reload
    other.reload
    assert_equal other, @transaction.reload.expense
    assert_not_equal netflix_due_after_first_link, @netflix.due_on, 'netflix due_on should roll back'
    assert_not_equal other_due_before, other.due_on, 'other due_on should advance'
    assert_nil @allocation.reload.spent_at, 'netflix allocation should be unspent again'
  end

  test 'unlink reverses everything' do
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    ExpenseLinker.unlink(transaction: @transaction)

    assert_nil @transaction.reload.expense
    assert_equal Date.new(2026, 2, 14), @netflix.reload.due_on
    assert_nil @allocation.reload.spent_at
    assert_nil @allocation.spent_by_transaction
    assert_equal 7.99, @netflix.bucket_balance.to_f
  end

  test 'link still flips FK and advances due_on when expense has no funded allocations' do
    empty = @user.expenses.create!(name: 'Empty', amount: 10, cadence: 'monthly', due_on: Date.new(2026, 3, 1), funding_schedule: @schedule)

    assert_equal 0, empty.bucket_balance.to_f
    ExpenseLinker.link(transaction: @transaction, expense: empty)

    assert_equal empty, @transaction.reload.expense
    assert_equal Date.new(2026, 4, 1), empty.reload.due_on
  end

  test 'unlink is a no-op when the transaction has no expense' do
    assert_nothing_raised do
      ExpenseLinker.unlink(transaction: @transaction)
    end
    assert_nil @transaction.expense
  end
end
