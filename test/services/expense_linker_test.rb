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

  test 'link draws the transaction down from the bucket and sets the expense' do
    assert_equal 7.99, @netflix.bucket_balance.to_f
    original_due_on = @netflix.due_on

    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    assert_equal 0, @netflix.reload.bucket_balance.to_f # capped at the 7.99 available
    assert_equal @netflix, @transaction.reload.expense
    assert_equal original_due_on, @netflix.due_on, 'due dates are calendar-driven; linking never moves them'

    spent = @allocation.reload
    assert_equal 7.99, spent.spent_amount.to_f
    assert spent.spent_at.present?
    assert_equal 1, AllocationSpend.where(spent_by_transaction: @transaction).count
  end

  test 'link against an already-linked transaction unlinks the prior expense first' do
    other = @user.expenses.create!(name: 'Other', amount: 50, cadence: 'monthly', due_on: Date.new(2026, 2, 20), funding_schedule: @schedule)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    ExpenseLinker.link(transaction: @transaction, expense: other)

    assert_equal other, @transaction.reload.expense
    assert_equal 7.99, @netflix.reload.bucket_balance.to_f, 'netflix bucket restored'
    assert_equal 0, @allocation.reload.spent_amount.to_f, 'netflix allocation unspent again'
    assert_equal 0, AllocationSpend.where(spent_by_transaction: @transaction).joins(:allocation)
                                   .where(allocations: { expense_id: @netflix.id }).count
  end

  test 'unlink reverses everything' do
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    ExpenseLinker.unlink(transaction: @transaction)

    assert_nil @transaction.reload.expense
    assert_equal 7.99, @netflix.reload.bucket_balance.to_f
    assert_equal 0, @allocation.reload.spent_amount.to_f
    assert_nil @allocation.spent_at
    assert_equal 0, AllocationSpend.where(spent_by_transaction: @transaction).count
  end

  test 'link still flips the FK when the expense has no funded allocations' do
    empty = @user.expenses.create!(name: 'Empty', amount: 10, cadence: 'monthly', due_on: Date.new(2026, 3, 1), funding_schedule: @schedule)

    assert_equal 0, empty.bucket_balance.to_f
    ExpenseLinker.link(transaction: @transaction, expense: empty)

    assert_equal empty, @transaction.reload.expense
    assert_equal 0, empty.reload.bucket_balance.to_f
  end

  test 'unlink is a no-op when the transaction has no expense' do
    assert_nothing_raised do
      ExpenseLinker.unlink(transaction: @transaction)
    end
    assert_nil @transaction.expense
  end

  test 'destroying a linked transaction unlinks it first so the bucket restores cleanly' do
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)
    assert_equal 0, @netflix.reload.bucket_balance.to_f

    @transaction.destroy!

    assert_equal 7.99, @netflix.reload.bucket_balance.to_f, 'bucket restored'
    assert_equal 0, @allocation.reload.spent_amount.to_f
    assert_nil @allocation.spent_at
  end

  test 'partial link: transaction smaller than the bucket leaves the residual in the bucket' do
    # Fully fund Netflix: one extra $8.00 allocation so bucket = 7.99 + 8.00 = 15.99
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)
    assert_equal 15.99, @netflix.bucket_balance.to_f

    partial = Transaction.create!(name: 'PARTIAL NETFLIX', amount: 5.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)

    assert_equal 10.99, @netflix.reload.bucket_balance.to_f
    assert_equal @netflix, partial.reload.expense
  end

  test 'partial link spends the oldest allocation fully and the next one partially' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)

    first = @allocation.reload
    second.reload

    assert_equal 7.99, first.spent_amount.to_f, 'oldest allocation fully consumed'
    assert_equal 2.01, second.spent_amount.to_f, 'next allocation takes the remainder'
    assert_equal 5.99, @netflix.reload.bucket_balance.to_f, '15.99 - 10.00'
    assert_equal 2, AllocationSpend.where(spent_by_transaction: partial).count, 'one spend row per touched allocation'
  end

  test 'unlink restores a partial link cleanly' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)
    partial = Transaction.create!(name: 'PARTIAL', amount: 10.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: partial, expense: @netflix)
    ExpenseLinker.unlink(transaction: partial)

    assert_nil partial.reload.expense
    assert_equal 15.99, @netflix.reload.bucket_balance.to_f, 'bucket fully restored'

    [ @allocation, second ].each do |allocation|
      allocation.reload
      assert_equal 0, allocation.spent_amount.to_f
      assert_nil allocation.spent_at
    end
    assert_equal 0, AllocationSpend.where(spent_by_transaction: partial).count
  end

  test 'link caps consumption at bucket_balance when the transaction exceeds it' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    overpay = Transaction.create!(name: 'OVERPAY', amount: 99.00, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: overpay, expense: @netflix)

    assert_equal 0, @netflix.reload.bucket_balance.to_f, 'bucket fully drained, never negative'
    assert_equal @netflix, overpay.reload.expense
  end

  test 'several transactions share one expense bucket (shared draw-down)' do
    # Fully fund Netflix: 7.99 (oldest) + 8.00 = 15.99
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    charge_a = Transaction.create!(name: 'CHARGE A', amount: 6.00, bank_account: bank_accounts(:chase_checking))
    charge_b = Transaction.create!(name: 'CHARGE B', amount: 9.99, bank_account: bank_accounts(:chase_checking))

    ExpenseLinker.link(transaction: charge_a, expense: @netflix) # 6.00 from the oldest allocation
    ExpenseLinker.link(transaction: charge_b, expense: @netflix) # 1.99 residual of oldest + 8.00 of second

    assert_equal @netflix, charge_a.reload.expense
    assert_equal @netflix, charge_b.reload.expense
    assert_equal 0, @netflix.reload.bucket_balance.to_f, 'both charges drained the shared bucket'

    first = @allocation.reload
    assert_equal 7.99, first.spent_amount.to_f, 'oldest allocation drawn by both charges'
    assert_equal 8.00, second.reload.spent_amount.to_f
    assert_equal 2, AllocationSpend.where(allocation: first).count, 'one allocation spent by two transactions'
  end

  test 'unlinking one of several shared transactions returns only its share' do
    second_event = @schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    second = Allocation.create!(funding_event: second_event, expense: @netflix, amount: 8.00, funded_at: Time.current)

    charge_a = Transaction.create!(name: 'CHARGE A', amount: 6.00, bank_account: bank_accounts(:chase_checking))
    charge_b = Transaction.create!(name: 'CHARGE B', amount: 9.99, bank_account: bank_accounts(:chase_checking))
    ExpenseLinker.link(transaction: charge_a, expense: @netflix)
    ExpenseLinker.link(transaction: charge_b, expense: @netflix)

    ExpenseLinker.unlink(transaction: charge_a)

    assert_nil charge_a.reload.expense
    assert_equal @netflix, charge_b.reload.expense, 'the other charge stays linked'
    assert_equal 6.00, @netflix.reload.bucket_balance.to_f, "only charge_a's 6.00 returns"
    assert_equal 1.99, @allocation.reload.spent_amount.to_f, "charge_b's residual stays on the oldest allocation"
    assert_equal 8.00, second.reload.spent_amount.to_f
  end
end
