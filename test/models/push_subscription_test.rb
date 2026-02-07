require 'test_helper'

class PushSubscriptionTest < ActiveSupport::TestCase
  test 'valid push subscription' do
    subscription = PushSubscription.new(
      user: users(:johndoe),
      endpoint: "https://fcm.googleapis.com/fcm/send/unique-endpoint",
      p256dh_key: "test-p256dh",
      auth_key: "test-auth"
    )

    assert subscription.valid?
  end

  test 'requires endpoint' do
    subscription = PushSubscription.new(
      user: users(:johndoe),
      p256dh_key: "test-p256dh",
      auth_key: "test-auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
  end

  test 'requires p256dh_key' do
    subscription = PushSubscription.new(
      user: users(:johndoe),
      endpoint: "https://fcm.googleapis.com/fcm/send/unique-endpoint",
      auth_key: "test-auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:p256dh_key], "can't be blank"
  end

  test 'requires auth_key' do
    subscription = PushSubscription.new(
      user: users(:johndoe),
      endpoint: "https://fcm.googleapis.com/fcm/send/unique-endpoint",
      p256dh_key: "test-p256dh"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:auth_key], "can't be blank"
  end

  test 'requires unique endpoint' do
    subscription = PushSubscription.new(
      user: users(:janedoe),
      endpoint: push_subscriptions(:johndoe_desktop).endpoint,
      p256dh_key: "test-p256dh",
      auth_key: "test-auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "has already been taken"
  end

  test 'belongs to user' do
    subscription = push_subscriptions(:johndoe_desktop)

    assert_equal users(:johndoe), subscription.user
  end

  test 'destroying user destroys push subscriptions' do
    user = User.create!(
      first_name: "Push",
      last_name: "Test",
      email_address: "pushtest_#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )

    subscription = PushSubscription.create!(
      user: user,
      endpoint: "https://fcm.googleapis.com/fcm/send/destroy-test",
      p256dh_key: "test-key",
      auth_key: "test-auth"
    )

    user.destroy

    assert_nil PushSubscription.find_by(id: subscription.id)
  end
end
