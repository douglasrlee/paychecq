require 'test_helper'

class PushNotificationServiceTest < ActiveSupport::TestCase
  MockResponse = Struct.new(:code, :body)

  setup do
    @user = users(:johndoe)
    @original_payload_send = WebPush.method(:payload_send)
    @original_vapid_public_key = Rails.application.config.web_push.vapid_public_key
    @original_vapid_private_key = Rails.application.config.web_push.vapid_private_key
    Rails.application.config.web_push.vapid_public_key = 'test-public-key'
    Rails.application.config.web_push.vapid_private_key = 'test-private-key'
  end

  teardown do
    WebPush.define_singleton_method(:payload_send, @original_payload_send)
    Rails.application.config.web_push.vapid_public_key = @original_vapid_public_key
    Rails.application.config.web_push.vapid_private_key = @original_vapid_private_key
  end

  test 'does nothing with empty transactions' do
    sent_count = 0
    WebPush.define_singleton_method(:payload_send) { |**| sent_count += 1 }

    PushNotificationService.notify_new_transactions(user: @user, transactions: [])

    assert_equal 0, sent_count
  end

  test 'does nothing when user has no subscriptions' do
    user = users(:janedoe)
    sent_count = 0
    WebPush.define_singleton_method(:payload_send) { |**| sent_count += 1 }

    transactions = [ build_transaction('Starbucks', 5.50) ]
    PushNotificationService.notify_new_transactions(user: user, transactions: transactions)

    assert_equal 0, sent_count
  end

  test 'sends individual notifications for 1-5 transactions' do
    payloads = []
    WebPush.define_singleton_method(:payload_send) { |**args| payloads << args }

    transactions = [
      build_transaction('Starbucks', 5.50),
      build_transaction('Amazon', 23.99)
    ]

    PushNotificationService.notify_new_transactions(user: @user, transactions: transactions)

    # 2 transactions * 2 subscriptions (johndoe_desktop + johndoe_mobile) = 4 pushes
    assert_equal 4, payloads.size

    first_payload = JSON.parse(payloads.first[:message])
    assert_equal 'New Transaction', first_payload['title']
    assert_includes first_payload['body'], 'Starbucks'
    assert_includes first_payload['body'], '$5.50'
  end

  test 'sends summary notification for 6+ transactions' do
    payloads = []
    WebPush.define_singleton_method(:payload_send) { |**args| payloads << args }

    transactions = 7.times.map { |i| build_transaction("Store #{i}", 10.00 + i) }

    PushNotificationService.notify_new_transactions(user: @user, transactions: transactions)

    # 1 summary * 2 subscriptions = 2 pushes
    assert_equal 2, payloads.size

    payload = JSON.parse(payloads.first[:message])
    assert_equal 'New Transactions', payload['title']
    assert_equal '7 new transactions added.', payload['body']
  end

  test 'removes expired subscriptions' do
    mock_response = MockResponse.new('410', 'Gone')
    WebPush.define_singleton_method(:payload_send) { |**| raise WebPush::ExpiredSubscription.new(mock_response, 'fcm.googleapis.com') }

    transactions = [ build_transaction('Starbucks', 5.50) ]

    assert_difference 'PushSubscription.count', -2 do
      PushNotificationService.notify_new_transactions(user: @user, transactions: transactions)
    end
  end

  test 'logs and reports other push errors' do
    mock_response = MockResponse.new('500', 'Internal Server Error')
    WebPush.define_singleton_method(:payload_send) { |**| raise WebPush::ResponseError.new(mock_response, 'fcm.googleapis.com') }

    errors_sent = []
    original_send_error = begin
      Appsignal.method(:send_error)
    rescue StandardError
      nil
    end
    Appsignal.define_singleton_method(:send_error) { |e| errors_sent << e }

    transactions = [ build_transaction('Starbucks', 5.50) ]
    PushNotificationService.notify_new_transactions(user: @user, transactions: transactions)

    assert_equal 2, errors_sent.size
  ensure
    Appsignal.define_singleton_method(:send_error, original_send_error) if original_send_error
  end

  private

  def build_transaction(name, amount)
    Transaction.new(id: SecureRandom.uuid, name: name, amount: amount)
  end
end
