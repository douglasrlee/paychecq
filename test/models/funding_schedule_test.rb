require 'test_helper'

class FundingScheduleTest < ActiveSupport::TestCase
  setup { @user = users(:johndoe) }

  def build(**attrs)
    @user.funding_schedules.new(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1), **attrs)
  end

  test 'is valid with required fields' do
    assert build.valid?
  end

  test 'requires name' do
    schedule = build(name: nil)

    assert_not schedule.valid?
    assert_includes schedule.errors[:name], "can't be blank"
  end

  test 'requires cadence in allowed set' do
    schedule = build(cadence: 'fortnightly')

    assert_not schedule.valid?
    assert_includes schedule.errors[:cadence], 'must be selected'
  end

  test 'requires start_date' do
    schedule = build(start_date: nil)

    assert_not schedule.valid?
    assert_includes schedule.errors[:start_date], "can't be blank"
  end

  test 'semimonthly requires second_day_of_month' do
    schedule = build(cadence: 'semimonthly')

    assert_not schedule.valid?
    assert_includes schedule.errors[:second_day_of_month], "can't be blank"
  end

  test 'semimonthly second_day_of_month must be in 1..31' do
    schedule = build(cadence: 'semimonthly', second_day_of_month: 32)

    assert_not schedule.valid?
    assert_includes schedule.errors[:second_day_of_month], 'must be a day from 1 to 31'
  end

  test 'non-semimonthly cadences reject second_day_of_month' do
    schedule = build(cadence: 'monthly', second_day_of_month: 15)

    assert_not schedule.valid?
    assert_includes schedule.errors[:second_day_of_month], 'must be blank'
  end

  test 'semimonthly rejects second_day_of_month equal to start_date day' do
    schedule = build(cadence: 'semimonthly', start_date: Date.new(2026, 1, 15), second_day_of_month: 15)

    assert_not schedule.valid?
    assert_includes schedule.errors[:second_day_of_month], "must be different from the first occurrence's day"
  end

  test 'weekly next_occurrences advances by 7 days' do
    schedule = build(cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    dates = schedule.next_occurrences(count: 3, after: Date.new(2026, 1, 1))

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 8), Date.new(2026, 1, 15) ], dates
  end

  test 'biweekly next_occurrences advances by 14 days' do
    schedule = build(cadence: 'biweekly', start_date: Date.new(2026, 1, 1))

    dates = schedule.next_occurrences(count: 3, after: Date.new(2026, 1, 15))

    assert_equal [ Date.new(2026, 1, 15), Date.new(2026, 1, 29), Date.new(2026, 2, 12) ], dates
  end

  test 'monthly next_occurrences clamps to last day of short months' do
    schedule = build(cadence: 'monthly', start_date: Date.new(2026, 1, 31))

    dates = schedule.next_occurrences(count: 4, after: Date.new(2026, 1, 31))

    assert_equal [ Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 31), Date.new(2026, 4, 30) ], dates
  end

  test 'semimonthly next_occurrences alternates between the two days' do
    schedule = build(cadence: 'semimonthly', start_date: Date.new(2026, 1, 1), second_day_of_month: 15)

    dates = schedule.next_occurrences(count: 4, after: Date.new(2026, 1, 1))

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 15), Date.new(2026, 2, 1), Date.new(2026, 2, 15) ], dates
  end

  test 'semimonthly clamps the late day to last of month in February' do
    schedule = build(cadence: 'semimonthly', start_date: Date.new(2026, 1, 15), second_day_of_month: 31)

    dates = schedule.next_occurrences(count: 4, after: Date.new(2026, 1, 15))

    assert_equal [ Date.new(2026, 1, 15), Date.new(2026, 1, 31), Date.new(2026, 2, 15), Date.new(2026, 2, 28) ], dates
  end

  test 'materialize_events_through creates events from start_date through end_date when clean' do
    schedule = @user.funding_schedules.create!(name: 'New paycheck', cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    events = schedule.materialize_events_through(end_date: Date.new(2026, 1, 22))

    occurs_on = events.map(&:occurs_on)
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 8), Date.new(2026, 1, 15), Date.new(2026, 1, 22) ], occurs_on
  end

  test 'materialize_events_through picks up where the last event left off' do
    schedule = @user.funding_schedules.create!(name: 'Picked up', cadence: 'weekly', start_date: Date.new(2026, 1, 1))
    schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 8))

    events = schedule.materialize_events_through(end_date: Date.new(2026, 1, 22))

    assert_equal [ Date.new(2026, 1, 15), Date.new(2026, 1, 22) ], events.map(&:occurs_on)
  end

  test 'materialize_events_through is idempotent' do
    schedule = @user.funding_schedules.create!(name: 'Idem', cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    schedule.materialize_events_through(end_date: Date.new(2026, 1, 22))

    assert_no_difference 'schedule.funding_events.count' do
      schedule.materialize_events_through(end_date: Date.new(2026, 1, 22))
    end
  end

  test 'occurrence_count_between returns the exact count even past 100 occurrences' do
    schedule = @user.funding_schedules.create!(name: 'Weekly', cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    # 2 years of weekly = 105 paychecks. The old 100-cap would have undercounted this.
    count = schedule.occurrence_count_between(after: Date.new(2026, 1, 1), through: Date.new(2027, 12, 31))

    assert_equal 105, count
  end

  test 'occurrence_count_between returns 0 when through is before after' do
    schedule = @user.funding_schedules.create!(name: 'W', cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    assert_equal 0, schedule.occurrence_count_between(after: Date.new(2026, 2, 1), through: Date.new(2026, 1, 1))
  end

  test 'next_occurrences skips past dates and starts at first occurrence on or after after' do
    schedule = build(cadence: 'weekly', start_date: Date.new(2026, 1, 1))

    dates = schedule.next_occurrences(count: 2, after: Date.new(2026, 2, 1))

    assert_equal [ Date.new(2026, 2, 5), Date.new(2026, 2, 12) ], dates
  end
end
