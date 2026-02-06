require 'test_helper'

module Webhooks
  class PlaidControllerTest < ActionDispatch::IntegrationTest
    test 'returns ok and enqueues job when verification succeeds' do
      payload = { webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE', item_id: 'item_123' }

      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| nil }

      assert_enqueued_with(job: PlaidWebhookJob) do
        post webhooks_plaid_path,
             params: payload.to_json,
             headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'fake-jwt' }
      end

      assert_response :ok
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'returns unauthorized when JWT decode fails' do
      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| raise ::JWT::DecodeError, 'bad token' }

      post webhooks_plaid_path,
           params: { webhook_type: 'TRANSACTIONS' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'bad-jwt' }

      assert_response :unauthorized
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'returns unauthorized when JWT verification fails' do
      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| raise ::JWT::VerificationError, 'bad sig' }

      post webhooks_plaid_path,
           params: { webhook_type: 'TRANSACTIONS' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'bad-jwt' }

      assert_response :unauthorized
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'returns unauthorized when JWT is expired' do
      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| raise ::JWT::ExpiredSignature, 'expired' }

      post webhooks_plaid_path,
           params: { webhook_type: 'TRANSACTIONS' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'bad-jwt' }

      assert_response :unauthorized
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'returns unauthorized when Plaid API errors during verification' do
      PlaidService.define_singleton_method(:verify_webhook) do |_body, _header|
        raise Plaid::ApiError.new(response_body: '{}', code: 500, response_headers: {})
      end

      post webhooks_plaid_path,
           params: { webhook_type: 'TRANSACTIONS' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'bad-jwt' }

      assert_response :unauthorized
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'returns bad request for malformed JSON body' do
      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| nil }

      post webhooks_plaid_path,
           params: 'not valid json{{{',
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'fake-jwt' }

      assert_response :bad_request
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end

    test 'does not require authentication' do
      PlaidService.define_singleton_method(:verify_webhook) { |_body, _header| nil }

      post webhooks_plaid_path,
           params: { webhook_type: 'TRANSACTIONS' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Plaid-Verification' => 'fake-jwt' }

      assert_response :ok
    ensure
      PlaidService.singleton_class.remove_method(:verify_webhook)
    end
  end
end
