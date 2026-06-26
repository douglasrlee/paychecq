require 'test_helper'

class GoalTest < ActiveSupport::TestCase
  setup do
    @user = users(:johndoe)
    @schedule = funding_schedules(:paycheck)
  end

  def build(**attrs)
    @user.goals.new(
      funding_schedule: @schedule,
      name: 'Vacation',
      amount: 1200.00,
      cadence: 'yearly',
      due_on: Date.new(2026, 12, 1),
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
    goal = build(funding_schedule: other_schedule)

    assert_not goal.valid?
    assert_includes goal.errors[:funding_schedule_id], 'must belong to you'
  end

  test 'monthly next_due_on rolls forward and clamps short months' do
    goal = build(cadence: 'monthly', due_on: Date.new(2026, 1, 31))

    assert_equal Date.new(2026, 2, 28), goal.next_due_on(after: Date.new(2026, 2, 1))
    assert_equal Date.new(2026, 3, 31), goal.next_due_on(after: Date.new(2026, 3, 1))
  end

  test 'quarterly next_due_on rolls forward by 3 months' do
    goal = build(cadence: 'quarterly', due_on: Date.new(2026, 1, 15))

    assert_equal Date.new(2026, 4, 15), goal.next_due_on(after: Date.new(2026, 4, 1))
    assert_equal Date.new(2026, 7, 15), goal.next_due_on(after: Date.new(2026, 5, 1))
  end

  test 'semiannual next_due_on rolls forward and clamps Aug 31 to Feb 28' do
    goal = build(cadence: 'semiannual', due_on: Date.new(2025, 8, 31))

    assert_equal Date.new(2026, 2, 28), goal.next_due_on(after: Date.new(2026, 1, 1))
    assert_equal Date.new(2026, 8, 31), goal.next_due_on(after: Date.new(2026, 3, 1))
  end

  test 'yearly next_due_on clamps Feb 29 leap day to Feb 28 next year' do
    goal = build(cadence: 'yearly', due_on: Date.new(2024, 2, 29))

    assert_equal Date.new(2025, 2, 28), goal.next_due_on(after: Date.new(2025, 1, 1))
    assert_equal Date.new(2026, 2, 28), goal.next_due_on(after: Date.new(2026, 1, 1))
    assert_equal Date.new(2028, 2, 29), goal.next_due_on(after: Date.new(2027, 3, 1))
  end

  test 'next_due_on returns the stored due_on when after is in the past' do
    goal = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14))

    assert_equal Date.new(2026, 2, 14), goal.next_due_on(after: Date.new(2026, 1, 1))
  end

  test 'bucket_balance sums only funded allocations' do
    goal = goals(:janes_goal) # janes_goal_first ($8.00) funded, second ($7.99) pending

    assert_equal 8.00, goal.bucket_balance.to_f
  end

  test 'off_track? is true when any allocation is pending' do
    goal = goals(:janes_goal) # fixture has a pending allocation on janes_paycheck_second

    assert goal.off_track?
  end

  test 'off_track? is false when all allocations are funded' do
    goal = goals(:janes_new_car) # fixture has no allocations

    assert_not goal.off_track?
  end

  test 'fully_funded? is false until the bucket covers the target amount' do
    # janes_goal has $8.00 funded against a $3,000 target.
    assert_not goals(:janes_goal).fully_funded?
  end

  test 'fully_funded? is true once the bucket covers the target amount' do
    goal = goals(:janes_goal)
    event = goal.funding_schedule.funding_events.create!(occurs_on: Date.new(2026, 2, 1))
    Allocation.create!(funding_event: event, goal: goal, amount: goal.amount, funded_at: Time.current)

    assert goal.fully_funded?
  end

  test 'past_due is true when due_on is before today' do
    travel_to Date.new(2026, 3, 1) do
      assert build(due_on: Date.new(2026, 2, 14)).past_due?
      assert_not build(due_on: Date.new(2026, 3, 1)).past_due?
      assert_not build(due_on: Date.new(2026, 4, 1)).past_due?
    end
  end

  test 'per_paycheck_amount divides amount by paychecks until next due' do
    # Biweekly schedule from Jan 1, 2026 -> Jan 1, 15, 29, Feb 12, 26, ...
    # As of Jan 5, next due Feb 14 -> paychecks are Jan 15, 29, Feb 12 = 3.
    travel_to Date.new(2026, 1, 5) do
      goal = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14), amount: 9.99)
      assert_in_delta 3.33, goal.per_paycheck_amount.to_f, 0.01 # 9.99 / 3
    end
  end

  test 'bump_due_backward! recedes one cycle for each cadence' do
    cases = {
      'monthly' => [ Date.new(2026, 4, 15), Date.new(2026, 3, 15) ],
      'quarterly' => [ Date.new(2026, 4, 15), Date.new(2026, 1, 15) ],
      'semiannual' => [ Date.new(2026, 6, 15), Date.new(2025, 12, 15) ],
      'yearly' => [ Date.new(2026, 4, 15), Date.new(2025, 4, 15) ]
    }

    cases.each do |cadence, (from, to)|
      goal = build(cadence: cadence, due_on: from)
      goal.save!
      goal.bump_due_backward!
      assert_equal to, goal.reload.due_on, "expected #{cadence} recede #{from} -> #{to}"
    end
  end

  test 'per_paycheck_amount handles a past-due goal by rolling forward' do
    # As of Mar 1, due Jan 14 (past) -> next_due rolls to Feb 14 then Mar 14.
    # Paychecks between Mar 1 and Mar 14: Mar 12 only = 1.
    travel_to Date.new(2026, 3, 1) do
      goal = build(cadence: 'monthly', due_on: Date.new(2026, 1, 14), amount: 12)
      assert_equal 12.00, goal.per_paycheck_amount.to_f # 12 / 1
    end
  end

  test 'per_paycheck_amount subtracts money already in the bucket' do
    # 3 paychecks until due (Jan 15, 29, Feb 12). $9.99 target with $3 funded
    # leaves $6.99 to move over 3 paychecks = $2.33.
    travel_to Date.new(2026, 1, 5) do
      goal = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14), amount: 9.99)
      goal.save!
      Allocation.create!(funding_event: funding_events(:paycheck_first), goal: goal, amount: 3, funded_at: Time.current)

      assert_in_delta 2.33, goal.per_paycheck_amount.to_f, 0.01
    end
  end

  test 'per_paycheck_amount is zero once the bucket is fully funded' do
    travel_to Date.new(2026, 1, 5) do
      goal = build(cadence: 'monthly', due_on: Date.new(2026, 2, 14), amount: 9.99)
      goal.save!
      Allocation.create!(funding_event: funding_events(:paycheck_first), goal: goal, amount: 9.99, funded_at: Time.current)

      assert_equal 0, goal.per_paycheck_amount.to_f
    end
  end
end
