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

  test 'exchange_public_token returns response on success' do
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-123',
          item_id: 'item-sandbox-456',
          request_id: 'req-123'
        }.to_json
      )

    result = PlaidService.exchange_public_token('public-sandbox-token')

    assert_equal 'access-sandbox-123', result.access_token
    assert_equal 'item-sandbox-456', result.item_id
  end

  test 'exchange_public_token raises on Plaid API error' do
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_PUBLIC_TOKEN',
          error_message: 'The public token is invalid',
          request_id: 'req-error'
        }.to_json
      )

    assert_raises(Plaid::ApiError) do
      PlaidService.exchange_public_token('invalid-token')
    end
  end

  test 'get_institution_logo returns logo on success' do
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: {
            institution_id: 'ins_1',
            name: 'Test Bank',
            logo: 'base64logodata'
          },
          request_id: 'req-123'
        }.to_json
      )

    result = PlaidService.get_institution_logo('ins_1')

    assert_equal 'base64logodata', result
  end

  test 'get_institution_logo returns nil on Plaid API error' do
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_INSTITUTION',
          error_message: 'Institution not found',
          request_id: 'req-error'
        }.to_json
      )

    result = PlaidService.get_institution_logo('invalid_ins')

    assert_nil result
  end

  test 'get_accounts returns accounts on success' do
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [
            {
              account_id: 'acc-123',
              name: 'Checking',
              mask: '1234',
              type: 'depository',
              subtype: 'checking',
              balances: { available: 1000.00, current: 1050.00 }
            }
          ],
          request_id: 'req-123'
        }.to_json
      )

    result = PlaidService.get_accounts('access-token')

    assert_equal 1, result.length
    assert_equal 'acc-123', result.first.account_id
  end

  test 'get_accounts raises on Plaid API error' do
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_ACCESS_TOKEN',
          error_message: 'The access token is invalid',
          request_id: 'req-error'
        }.to_json
      )

    assert_raises(Plaid::ApiError) do
      PlaidService.get_accounts('invalid-token')
    end
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

  test 'sync_transactions returns added, modified, removed and cursor' do
    stub_request(:post, 'https://sandbox.plaid.com/transactions/sync')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          added: [ { transaction_id: 'txn_1', account_id: 'acc_1', name: 'Coffee', amount: 4.50,
                      date: '2026-02-01', authorized_date: '2026-02-01', merchant_name: 'Starbucks',
                      pending: false, payment_channel: 'in store',
                      personal_finance_category: { primary: 'FOOD_AND_DRINK', detailed: 'COFFEE' },
                      logo_url: nil, merchant_entity_id: nil, iso_currency_code: 'USD' } ],
          modified: [],
          removed: [],
          next_cursor: 'cursor_abc',
          has_more: false,
          request_id: 'req-123'
        }.to_json
      )

    result = PlaidService.sync_transactions('access-token')

    assert_equal 1, result[:added].length
    assert_equal 'txn_1', result[:added].first.transaction_id
    assert_empty result[:modified]
    assert_empty result[:removed]
    assert_equal 'cursor_abc', result[:cursor]
  end

  test 'sync_transactions paginates when has_more is true' do
    stub_request(:post, 'https://sandbox.plaid.com/transactions/sync')
      .to_return(
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: {
            added: [ { transaction_id: 'txn_1', account_id: 'acc_1', name: 'Page 1', amount: 1.00,
                        date: '2026-02-01', pending: false, payment_channel: 'online',
                        iso_currency_code: 'USD' } ],
            modified: [], removed: [], next_cursor: 'cursor_page2', has_more: true, request_id: 'req-1'
          }.to_json },
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: {
            added: [ { transaction_id: 'txn_2', account_id: 'acc_1', name: 'Page 2', amount: 2.00,
                        date: '2026-02-02', pending: false, payment_channel: 'online',
                        iso_currency_code: 'USD' } ],
            modified: [], removed: [], next_cursor: 'cursor_final', has_more: false, request_id: 'req-2'
          }.to_json }
      )

    result = PlaidService.sync_transactions('access-token')

    assert_equal 2, result[:added].length
    assert_equal 'cursor_final', result[:cursor]
  end

  test 'sync_transactions raises on Plaid API error' do
    stub_request(:post, 'https://sandbox.plaid.com/transactions/sync')
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

    assert_raises(Plaid::ApiError) do
      PlaidService.sync_transactions('invalid-token')
    end
  end
end
