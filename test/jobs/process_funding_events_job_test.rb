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
