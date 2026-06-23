require 'test_helper'

class AllocationTest < ActiveSupport::TestCase
  setup do
    @event = funding_events(:paycheck_first)
    @expense = expenses(:car_insurance) # netflix already has an allocation for paycheck_first
  end

  test 'is valid with required fields' do
    allocation = Allocation.new(funding_event: @event, expense: @expense, amount: 10.00)

    assert allocation.valid?
  end

  test 'requires amount' do
    allocation = Allocation.new(funding_event: @event, expense: @expense)

    assert_not allocation.valid?
    assert_includes allocation.errors[:amount], "can't be blank"
  end

  test 'requires positive amount' do
    allocation = Allocation.new(funding_event: @event, expense: @expense, amount: 0)

    assert_not allocation.valid?
    assert_includes allocation.errors[:amount], 'must be greater than 0'
  end

  test 'enforces unique expense per funding_event' do
    duplicate = Allocation.new(funding_event: funding_events(:paycheck_first), expense: expenses(:netflix), amount: 5)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:expense_id], 'has already been taken'
  end

  test 'rejects spent_amount greater than amount' do
    allocation = Allocation.new(funding_event: @event, expense: @expense, amount: 5, spent_amount: 6)

    assert_not allocation.valid?
    assert_includes allocation.errors[:spent_amount], 'cannot exceed amount'
  end

  test 'rejects an allocation linked to both an expense and a goal' do
    allocation = Allocation.new(funding_event: @event, expense: @expense, goal: goals(:janes_goal), amount: 5)

    assert_not allocation.valid?
    assert_includes allocation.errors[:base], 'must belong to either an expense or a goal, not both'
  end

  test 'rejects an allocation linked to neither an expense nor a goal' do
    allocation = Allocation.new(funding_event: @event, amount: 5)

    assert_not allocation.valid?
    assert_includes allocation.errors[:base], 'must belong to either an expense or a goal, not both'
  end
end
