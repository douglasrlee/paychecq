require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'is valid with all required attributes' do
    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'test@example.com',
      password: 'password'
    )

    assert user.valid?
  end

  test 'is invalid without first_name' do
    user = User.new(
      last_name: 'User',
      email_address: 'test@example.com',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test 'is invalid without last_name' do
    user = User.new(
      first_name: 'Test',
      email_address: 'test@example.com',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test 'is invalid without email_address' do
    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test 'is invalid with duplicate email_address' do
    User.create!(
      first_name: 'Existing',
      last_name: 'User',
      email_address: 'duplicate@example.com',
      password: 'password'
    )

    user = User.new(
      first_name: 'New',
      last_name: 'User',
      email_address: 'duplicate@example.com',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], 'has already been taken'
  end

  test 'is invalid with duplicate email_address regardless of case' do
    User.create!(
      first_name: 'Existing',
      last_name: 'User',
      email_address: 'duplicate@example.com',
      password: 'password'
    )

    user = User.new(
      first_name: 'New',
      last_name: 'User',
      email_address: 'DUPLICATE@EXAMPLE.COM',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], 'has already been taken'
  end

  test 'is invalid with malformed email_address' do
    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'not-a-valid-email',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], 'is invalid'
  end

  test 'downcases and strips email_address' do
    user = User.new(email_address: ' DOWNCASED@EXAMPLE.COM ')

    assert_equal('downcased@example.com', user.email_address)
  end

  test 'is valid when email is on the allowlist' do
    original = ENV.fetch('ALLOWED_EMAILS', nil)
    ENV['ALLOWED_EMAILS'] = 'allowed@example.com, other@example.com'

    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'allowed@example.com',
      password: 'password'
    )

    assert user.valid?
  ensure
    ENV['ALLOWED_EMAILS'] = original
  end

  test 'is invalid when email is not on the allowlist' do
    original = ENV.fetch('ALLOWED_EMAILS', nil)
    ENV['ALLOWED_EMAILS'] = 'allowed@example.com'

    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'rejected@example.com',
      password: 'password'
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], 'is not authorized to sign up'
  ensure
    ENV['ALLOWED_EMAILS'] = original
  end

  test 'is valid with any email when ALLOWED_EMAILS is unset' do
    original = ENV.fetch('ALLOWED_EMAILS', nil)
    ENV['ALLOWED_EMAILS'] = nil

    user = User.new(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'anyone@example.com',
      password: 'password'
    )

    assert user.valid?
  ensure
    ENV['ALLOWED_EMAILS'] = original
  end

  test 'free_to_spend is available balance minus funded unspent buckets' do
    user = users(:johndoe)
    user.expenses.destroy_all
    user.funding_schedules.destroy_all
    schedule = user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    expense = user.expenses.create!(name: 'Rent', amount: 100, cadence: 'monthly', due_on: Date.new(2026, 2, 1), funding_schedule: schedule)
    event = schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: event, expense: expense, amount: 100, funded_at: Time.current)

    # johndoe has $6,000 available across chase_checking + chase_savings.
    assert_equal 6000, user.available_balance.to_f
    assert_equal 100, user.allocated_in_buckets.to_f
    assert_equal 5900, user.free_to_spend.to_f
  end

  test 'free_to_spend ignores pending (unfunded) allocations' do
    user = users(:johndoe)
    user.expenses.destroy_all
    user.funding_schedules.destroy_all
    schedule = user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    expense = user.expenses.create!(name: 'Rent', amount: 100, cadence: 'monthly', due_on: Date.new(2026, 2, 1), funding_schedule: schedule)
    event = schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: event, expense: expense, amount: 100, funded_at: nil)

    assert_equal 0, user.allocated_in_buckets.to_f
    assert_equal 6000, user.free_to_spend.to_f
  end
end
