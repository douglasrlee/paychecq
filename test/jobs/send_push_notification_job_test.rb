require 'test_helper'

class SendPushNotificationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:johndoe)
    @original_notify = PushNotificationService.method(:notify_new_transactions)
  end

  teardown do
    PushNotificationService.define_singleton_method(:notify_new_transactions, @original_notify)
  end

  test 'calls PushNotificationService with user and transactions' do
    transaction = Transaction.create!(name: 'Test', amount: 10.00)
    notified_user = nil
    notified_transactions = nil

    PushNotificationService.define_singleton_method(:notify_new_transactions) do |user:, transactions:|
      notified_user = user
      notified_transactions = transactions
    end

    SendPushNotificationJob.perform_now(@user.id, [ transaction.id ])

    assert_equal @user, notified_user
    assert_equal [ transaction ], notified_transactions.to_a
  end

  test 'does nothing when user not found' do
    called = false
    PushNotificationService.define_singleton_method(:notify_new_transactions) { |**| called = true }

    SendPushNotificationJob.perform_now(SecureRandom.uuid, [ SecureRandom.uuid ])

    assert_not called
  end

  test 'does nothing when transactions not found' do
    called = false
    PushNotificationService.define_singleton_method(:notify_new_transactions) { |**| called = true }

    SendPushNotificationJob.perform_now(@user.id, [ SecureRandom.uuid ])

    assert_not called
  end
end
