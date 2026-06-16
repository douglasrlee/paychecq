require 'test_helper'

class FundingEventTest < ActiveSupport::TestCase
  setup { @schedule = funding_schedules(:paycheck) }

  test 'is valid with required fields' do
    event = FundingEvent.new(funding_schedule: @schedule, occurs_on: Date.new(2026, 2, 1))

    assert event.valid?
  end

  test 'requires occurs_on' do
    event = FundingEvent.new(funding_schedule: @schedule)

    assert_not event.valid?
    assert_includes event.errors[:occurs_on], "can't be blank"
  end

  test 'enforces unique occurs_on per funding_schedule' do
    duplicate = FundingEvent.new(funding_schedule: @schedule, occurs_on: funding_events(:paycheck_first).occurs_on)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:occurs_on], 'has already been taken'
  end

  test 'allows same occurs_on for different funding_schedule' do
    event = FundingEvent.new(funding_schedule: funding_schedules(:side_gig), occurs_on: funding_events(:paycheck_first).occurs_on)

    assert event.valid?
  end

  test 'destroys allocations on destroy' do
    event = funding_events(:paycheck_first)

    assert_difference 'Allocation.count', -1 do
      event.destroy
    end
  end
end
