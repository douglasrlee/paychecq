require 'test_helper'

class ProcessFundingEventsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:johndoe)
    @user.expenses.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @expense = @user.expenses.create!(name: 'Netflix', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 1, 29), funding_schedule: @schedule)
  end

  test 'materializes, proposes, and funds end-to-end' do
    travel_to Date.new(2026, 1, 16) do
      ProcessFundingEventsJob.perform_now
    end

    events = @schedule.funding_events.order(:occurs_on)
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 15) ], events.map(&:occurs_on)
    assert events.all? { |e| e.processed_at.present? }, 'every materialized event should be marked processed'

    funded = @expense.allocations.where.not(funded_at: nil)
    assert_equal 2, funded.count, 'both allocations should be funded with the bank balance covering them'
  end

  test 'is a no-op on the second run (idempotent)' do
    travel_to Date.new(2026, 1, 16) do
      ProcessFundingEventsJob.perform_now

      assert_no_difference [ 'FundingEvent.count', 'Allocation.count' ] do
        ProcessFundingEventsJob.perform_now
      end
    end
  end

  test 'continues to next event when propose_for raises, logs + reports' do
    original_propose = AllocationEngine.method(:propose_for)
    original_send_error = Appsignal.method(:send_error)

    @schedule.materialize_events_through(end_date: Date.new(2026, 1, 16))
    raising_event = FundingEvent.find_by!(occurs_on: Date.new(2026, 1, 1))

    AllocationEngine.define_singleton_method(:propose_for) do |event|
      raise StandardError, 'simulated failure' if event == raising_event

      original_propose.call(event)
    end
    reported = nil
    Appsignal.define_singleton_method(:send_error) { |err| reported = err }

    travel_to(Date.new(2026, 1, 16)) { ProcessFundingEventsJob.perform_now }

    assert_kind_of StandardError, reported
    other = FundingEvent.find_by!(occurs_on: Date.new(2026, 1, 15))
    assert other.processed_at.present?, 'non-raising event should still get processed'
  ensure
    AllocationEngine.define_singleton_method(:propose_for, original_propose) if original_propose
    Appsignal.define_singleton_method(:send_error, original_send_error) if original_send_error
  end

  test 'continues to next user when fund_pending_for raises, logs + reports' do
    original_fund = AllocationEngine.method(:fund_pending_for)
    original_send_error = Appsignal.method(:send_error)
    failing_user = @user

    AllocationEngine.define_singleton_method(:fund_pending_for) do |user|
      raise StandardError, 'simulated failure' if user == failing_user

      original_fund.call(user)
    end
    reported = nil
    Appsignal.define_singleton_method(:send_error) { |err| reported = err }

    assert_nothing_raised do
      travel_to(Date.new(2026, 1, 16)) { ProcessFundingEventsJob.perform_now }
    end
    assert_kind_of StandardError, reported
  ensure
    AllocationEngine.define_singleton_method(:fund_pending_for, original_fund) if original_fund
    Appsignal.define_singleton_method(:send_error, original_send_error) if original_send_error
  end

  test 'flips previously-pending allocations on a later run when balance catches up' do
    @user.bank_accounts.update_all(available_balance: 0) # rubocop:disable Rails/SkipsModelValidations

    travel_to Date.new(2026, 1, 16) do
      ProcessFundingEventsJob.perform_now
    end

    assert @expense.allocations.exists?(funded_at: nil), 'allocations should be pending after first run'

    @user.bank_accounts.update_all(available_balance: 100) # rubocop:disable Rails/SkipsModelValidations
    travel_to Date.new(2026, 1, 16) do
      ProcessFundingEventsJob.perform_now
    end

    assert @expense.allocations.where(funded_at: nil).none?, 'no allocations should remain pending after second run'
  end
end
