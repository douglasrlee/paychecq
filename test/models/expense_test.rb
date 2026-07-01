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

  test 'bucket_balance sums only funded allocations' do
    expense = expenses(:netflix)

    assert_equal 8.00, expense.bucket_balance.to_f
  end

  test 'fully_funded? is true once the bucket covers the target amount' do
    expense = expenses(:netflix) # $22.99 target, $8.00 in bucket
    expense.allocations.create!(amount: 14.99, funded_at: Time.current)

    assert expense.fully_funded?
  end

  test 'fully_funded? is false when the bucket is under the target' do
    assert_not expenses(:netflix).fully_funded?
  end

  test 'off_track? is true when any allocation is pending' do
    expense = expenses(:netflix) # fixture has a pending allocation on paycheck_second

    assert expense.off_track?
  end

  test 'off_track? is false when all allocations are funded' do
    expense = expenses(:car_insurance)

    assert_not expense.off_track?
  end

  test 'off_track? is false when the current cycle is funded but a future cycle is queued' do
    # A fully-funded current cycle plus a pre-funded next-cycle allocation that
    # is still pending should NOT read as off-track.
    schedule = @user.funding_schedules.create!(name: 'Rent paycheck', cadence: 'monthly', start_date: Date.new(2026, 1, 1))
    expense = @user.expenses.create!(name: 'Rent', amount: 100, cadence: 'monthly',
                                     due_on: Date.new(2026, 2, 1), funding_schedule: schedule)
    e1 = schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    e2 = schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 15))
    expense.allocations.create!(funding_event: e1, amount: 100, funded_at: Time.current) # current cycle, in bucket
    expense.allocations.create!(funding_event: e2, amount: 50, funded_at: nil)           # next cycle, queued

    assert expense.bucket_balance >= expense.amount
    assert_not expense.off_track?
  end

  test 'current_due_on rolls forward to the next occurrence once the date passes' do
    travel_to Date.new(2026, 3, 1) do
      expense = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14))
      # Feb 14 already passed, so it shows the next occurrence.
      assert_equal Date.new(2026, 3, 14), expense.current_due_on
    end

    travel_to Date.new(2026, 3, 14) do
      expense = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14))
      # On the due date itself it stays put.
      assert_equal Date.new(2026, 3, 14), expense.current_due_on
    end

    travel_to Date.new(2026, 3, 15) do
      expense = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14))
      # The day after, it rolls to the following occurrence.
      assert_equal Date.new(2026, 4, 14), expense.current_due_on
    end
  end

  test 'per_paycheck_amount divides amount by paychecks until next due' do
    # Biweekly schedule from Jan 1, 2026 -> Jan 1, 15, 29, Feb 12, 26, ...
    # As of Jan 5, next due Feb 14 -> paychecks are Jan 15, 29, Feb 12 = 3.
    travel_to Date.new(2026, 1, 5) do
      expense = build(due_on: Date.new(2026, 2, 14), amount: 9.99)
      assert_in_delta 3.33, expense.per_paycheck_amount.to_f, 0.01 # 9.99 / 3
    end
  end

  test 'per_paycheck_amount handles a past-due expense by rolling forward' do
    # As of Mar 1, due Jan 14 (past) -> next_due rolls to Feb 14 then Mar 14.
    # Paychecks between Mar 1 and Mar 14: Mar 12 only = 1.
    travel_to Date.new(2026, 3, 1) do
      expense = build(due_on: Date.new(2026, 1, 14), amount: 12)
      assert_equal 12.00, expense.per_paycheck_amount.to_f # 12 / 1
    end
  end

  test 'per_paycheck_amount subtracts money already in the bucket' do
    # 3 paychecks until due (Jan 15, 29, Feb 12). $9.99 target with $3 funded
    # leaves $6.99 to move over 3 paychecks = $2.33.
    travel_to Date.new(2026, 1, 5) do
      expense = build(due_on: Date.new(2026, 2, 14), amount: 9.99)
      expense.save!
      Allocation.create!(funding_event: funding_events(:paycheck_first), expense: expense, amount: 3, funded_at: Time.current)

      assert_in_delta 2.33, expense.per_paycheck_amount.to_f, 0.01
    end
  end

  test 'per_paycheck_amount is zero once the bucket is fully funded' do
    travel_to Date.new(2026, 1, 5) do
      expense = build(due_on: Date.new(2026, 2, 14), amount: 9.99)
      expense.save!
      Allocation.create!(funding_event: funding_events(:paycheck_first), expense: expense, amount: 9.99, funded_at: Time.current)

      assert_equal 0, expense.per_paycheck_amount.to_f
    end
  end
end
