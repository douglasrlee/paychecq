require 'test_helper'

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:johndoe)
  end

  test 'create requires authentication' do
    post push_subscription_path, params: { push_subscription: { endpoint: "https://example.com" } }, as: :json

    assert_redirected_to new_session_path
  end

  test 'create saves a new subscription' do
    sign_in_as @user

    assert_difference 'PushSubscription.count', 1 do
      post push_subscription_path, params: {
        push_subscription: {
          endpoint: "https://fcm.googleapis.com/fcm/send/new-endpoint",
          keys: { p256dh: "new-p256dh", auth: "new-auth" }
        }
      }, as: :json
    end

    assert_response :created

    subscription = PushSubscription.find_by(endpoint: "https://fcm.googleapis.com/fcm/send/new-endpoint")
    assert_equal @user.id, subscription.user_id
    assert_equal "new-p256dh", subscription.p256dh_key
    assert_equal "new-auth", subscription.auth_key
  end

  test 'create updates existing subscription with same endpoint' do
    sign_in_as @user
    existing = push_subscriptions(:johndoe_desktop)

    assert_no_difference 'PushSubscription.count' do
      post push_subscription_path, params: {
        push_subscription: {
          endpoint: existing.endpoint,
          keys: { p256dh: "updated-p256dh", auth: "updated-auth" }
        }
      }, as: :json
    end

    assert_response :created
    assert_equal "updated-p256dh", existing.reload.p256dh_key
    assert_equal "updated-auth", existing.reload.auth_key
  end

  test 'create returns unprocessable entity for invalid data' do
    sign_in_as @user

    post push_subscription_path, params: {
      push_subscription: { endpoint: "", keys: { p256dh: "", auth: "" } }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test 'destroy requires authentication' do
    delete push_subscription_path, params: { endpoint: "https://example.com" }, as: :json

    assert_redirected_to new_session_path
  end

  test 'destroy removes the subscription' do
    sign_in_as @user
    subscription = push_subscriptions(:johndoe_desktop)

    assert_difference 'PushSubscription.count', -1 do
      delete push_subscription_path, params: { endpoint: subscription.endpoint }, as: :json
    end

    assert_response :ok
  end

  test 'destroy returns ok even when subscription not found' do
    sign_in_as @user

    delete push_subscription_path, params: { endpoint: "https://nonexistent.example.com" }, as: :json

    assert_response :ok
  end

  test 'destroy only removes current user subscriptions' do
    sign_in_as users(:janedoe)
    subscription = push_subscriptions(:johndoe_desktop)

    assert_no_difference 'PushSubscription.count' do
      delete push_subscription_path, params: { endpoint: subscription.endpoint }, as: :json
    end

    assert_response :ok
  end
end
