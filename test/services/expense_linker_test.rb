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

  test 'link/unlink round-trip preserves a Jan 31 due date through Feb clamping' do
    # Jan 31 -> bump_due_forward! clamps to Feb 28; bump_due_backward! from
    # Feb 28 would only return Jan 28, losing the original day. With
    # previous_due_on stored on the transaction, unlink restores exactly.
    quirky = @user.expenses.create!(name: 'Mortgage', amount: 100, cadence: 'monthly',
                                    due_on: Date.new(2026, 1, 31), funding_schedule: @schedule)
    event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: event, expense: quirky, amount: 100, funded_at: Time.current)
    txn = Transaction.create!(name: 'MORTGAGE', amount: 100, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: txn, expense: quirky)
    assert_equal Date.new(2026, 2, 28), quirky.reload.due_on, 'forward clamps Feb to 28'
    assert_equal Date.new(2026, 1, 31), txn.reload.previous_due_on

    ExpenseLinker.unlink(transaction: txn)

    assert_equal Date.new(2026, 1, 31), quirky.reload.due_on, 'unlink restores the original 31st'
    assert_nil txn.reload.previous_due_on
  end

  test 'destroying a linked transaction unlinks it first so the bucket and due_on restore cleanly' do
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)
    assert_equal 0, @netflix.reload.bucket_balance.to_f
    advanced_due = @netflix.due_on

    @transaction.destroy!

    assert_equal 7.99, @netflix.reload.bucket_balance.to_f, 'bucket restored'
    assert_not_equal advanced_due, @netflix.due_on, 'due_on rolled back'
    assert_nil @allocation.reload.spent_at
    assert_nil @allocation.spent_by_transaction_id
    assert_equal 0, @allocation.spent_amount.to_f
  end

  test 'partial link: transaction smaller than bucket leaves the residual in the bucket' do
    # Fully fund Netflix: one extra $8.00 allocation so bucket = 7.99 + 8.00 = 15.99
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)
    assert_equal 15.99, @netflix.bucket_balance.to_f

    partial = Transaction.create!(name: 'PARTIAL NETFLIX', amount: 5.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)

    assert_equal 10.99, @netflix.reload.bucket_balance.to_f
    assert_equal @netflix, partial.reload.expense
    assert_equal Date.new(2026, 3, 14), @netflix.due_on, 'due_on rolls forward even on partial'
  end

  test 'partial link spends oldest allocation fully and the next one partially' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)

    first = @allocation.reload
    second.reload

    assert_equal 7.99, first.spent_amount.to_f, 'oldest allocation fully consumed'
    assert_equal first.amount, first.spent_amount, 'oldest fully spent'
    assert_equal partial, first.spent_by_transaction

    assert_equal 2.01, second.spent_amount.to_f, 'next allocation takes the remainder'
    assert second.amount > second.spent_amount, 'next allocation has residual'
    assert_equal partial, second.spent_by_transaction

    assert_equal 5.99, @netflix.reload.bucket_balance.to_f, '15.99 - 10.00'
  end

  test 'unlink restores a partial link cleanly' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)
    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)
    ExpenseLinker.unlink(transaction: partial)

    assert_nil partial.reload.expense
    assert_equal Date.new(2026, 2, 14), @netflix.reload.due_on, 'due_on rolls back'
    assert_equal 15.99, @netflix.bucket_balance.to_f, 'bucket fully restored'

    [ @allocation, second ].each do |allocation|
      allocation.reload
      assert_equal 0, allocation.spent_amount.to_f
      assert_nil allocation.spent_at
      assert_nil allocation.spent_by_transaction
    end
  end

  test 'link caps consumption at bucket_balance when transaction exceeds it' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    overpay = Transaction.create!(name: 'OVERPAY', amount: 99.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: overpay, expense: @netflix)

    assert_equal 0, @netflix.reload.bucket_balance.to_f, 'bucket fully drained, never negative'
    assert_equal @netflix, overpay.reload.expense
  end

  test 'link skips allocations already spent by a prior transaction' do
    # Prior partial: a small transaction touched the first allocation.
    first_partial = Transaction.create!(name: 'PRIOR', amount: 3.00, bank_account: bank_accounts(:chase_checking))
    ExpenseLinker.link(transaction: first_partial, expense: @netflix)
    # @allocation now has spent_amount = 3.00, spent_by_transaction = first_partial.

    # New cycle: add a fresh funded allocation; bucket = $4.99 residual + $8.00 = $12.99.
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)
    assert_equal 12.99, @netflix.reload.bucket_balance.to_f

    next_txn = Transaction.create!(name: 'NEXT', amount: 8.00, bank_account: bank_accounts(:chase_checking))
    ExpenseLinker.link(transaction: next_txn, expense: @netflix)

    # The original allocation must NOT have been touched again — spent_by_transaction
    # stays pointed at first_partial, spent_amount unchanged.
    assert_equal first_partial, @allocation.reload.spent_by_transaction
    assert_equal 3.00, @allocation.spent_amount.to_f

    # The new allocation got fully consumed by the new transaction.
    second.reload
    assert_equal next_txn, second.spent_by_transaction
    assert_equal 8.00, second.spent_amount.to_f

    # Residual from the prior partial still sits in the bucket.
    assert_equal 4.99, @netflix.bucket_balance.to_f
  end
end
