require 'test_helper'

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe)
    @schedule = funding_schedules(:paycheck)
  end

  def build(**attrs)
    @user.expenses.new(
      funding_schedule: @schedule,
      name: 'Spotify',
      amount: 9.99,
      cadence: 'monthly',
      due_on: Date.new(2026, 2, 14),
      **attrs
    )
  end

  test 'is valid with required fields' do
    assert build.valid?
  end

  test 'requires name' do
    assert_includes build(name: nil).tap(&:valid?).errors[:name], "can't be blank"
  end

  test 'requires amount' do
    assert_includes build(amount: nil).tap(&:valid?).errors[:amount], "can't be blank"
  end

  test 'requires positive amount' do
    assert_includes build(amount: 0).tap(&:valid?).errors[:amount], 'must be greater than 0'
  end

  test 'requires cadence in allowed set' do
    assert_includes build(cadence: 'fortnightly').tap(&:valid?).errors[:cadence], 'must be selected'
  end

  test 'requires due_on' do
    assert_includes build(due_on: nil).tap(&:valid?).errors[:due_on], "can't be blank"
  end

  test 'rejects a funding schedule that belongs to another user' do
    other_schedule = funding_schedules(:janes_paycheck)
    expense = build(funding_schedule: other_schedule)

    assert_not expense.valid?
    assert_includes expense.errors[:funding_schedule_id], 'must belong to you'
  end

  test 'monthly next_due_on rolls forward and clamps short months' do
    expense = build(cadence: 'monthly', due_on: Date.new(2026, 1, 31))

    assert_equal Date.new(2026, 2, 28), expense.next_due_on(after: Date.new(2026, 2, 1))
    assert_equal Date.new(2026, 3, 31), expense.next_due_on(after: Date.new(2026, 3, 1))
  end

  test 'quarterly next_due_on rolls forward by 3 months' do
    expense = build(cadence: 'quarterly', due_on: Date.new(2026, 1, 15))

    assert_equal Date.new(2026, 4, 15), expense.next_due_on(after: Date.new(2026, 4, 1))
    assert_equal Date.new(2026, 7, 15), expense.next_due_on(after: Date.new(2026, 5, 1))
  end

  test 'semiannual next_due_on rolls forward and clamps Aug 31 to Feb 28' do
    expense = build(cadence: 'semiannual', due_on: Date.new(2025, 8, 31))

    assert_equal Date.new(2026, 2, 28), expense.next_due_on(after: Date.new(2026, 1, 1))
    assert_equal Date.new(2026, 8, 31), expense.next_due_on(after: Date.new(2026, 3, 1))
  end

  test 'yearly next_due_on clamps Feb 29 leap day to Feb 28 next year' do
    expense = build(cadence: 'yearly', due_on: Date.new(2024, 2, 29))

    assert_equal Date.new(2025, 2, 28), expense.next_due_on(after: Date.new(2025, 1, 1))
    assert_equal Date.new(2026, 2, 28), expense.next_due_on(after: Date.new(2026, 1, 1))
    assert_equal Date.new(2028, 2, 29), expense.next_due_on(after: Date.new(2027, 3, 1))
  end

  test 'next_due_on returns the stored due_on when after is in the past' do
    expense = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14))

    assert_equal Date.new(2026, 2, 14), expense.next_due_on(after: Date.new(2026, 1, 1))
  end

  test 'past_due is true when due_on is before today' do
    travel_to Date.new(2026, 3, 1) do
      assert build(due_on: Date.new(2026, 2, 14)).past_due?
      assert_not build(due_on: Date.new(2026, 3, 1)).past_due?
      assert_not build(due_on: Date.new(2026, 4, 1)).past_due?
    end
  end
end
