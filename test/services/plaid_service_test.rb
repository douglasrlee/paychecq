require 'test_helper'

class PlaidServiceTest < ActiveSupport::TestCase
  test 'create_link_token returns nil on Plaid API error' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'plaidtest@example.com',
      password: 'password'
    )

    stub_request(:post, 'https://sandbox.plaid.com/link/token/create')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_REQUEST',
          error_code: 'INVALID_FIELD',
          error_message: 'Invalid field',
          request_id: 'req-error'
        }.to_json
      )

    result = PlaidService.create_link_token(user)

    assert_nil result
  end

  test 'create_link_token returns link token on success' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'plaidtest_success@example.com',
      password: 'password'
    )

    stub_request(:post, 'https://sandbox.plaid.com/link/token/create')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          link_token: 'link-sandbox-test-token',
          expiration: 1.hour.from_now.iso8601,
          request_id: 'req-success'
        }.to_json
      )

    result = PlaidService.create_link_token(user)

    assert_equal 'link-sandbox-test-token', result
  end

  test 'remove_item returns false on Plaid API error' do
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_ACCESS_TOKEN',
          error_message: 'Invalid access token',
          request_id: 'req-error'
        }.to_json
      )

    result = PlaidService.remove_item('invalid_token')

    assert_equal false, result
  end

  test 'remove_item returns true on success' do
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { request_id: 'req-success' }.to_json
      )

    result = PlaidService.remove_item('valid_token')

    assert_equal true, result
  end
end
