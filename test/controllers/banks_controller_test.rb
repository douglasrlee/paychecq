require 'test_helper'

class BanksControllerTest < ActionDispatch::IntegrationTest
  # Valid 1x1 transparent PNG for logo tests
  VALID_PNG_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='.freeze

  setup { @user = users(:johndoe) }

  test 'create successfully links bank and creates accounts' do
    # Create a user without a bank
    user_without_bank = User.create!(
      first_name: 'New',
      last_name: 'User',
      email_address: 'newuser_create@example.com',
      password: 'password'
    )
    sign_in_as(user_without_bank)

    # Mock Plaid token exchange
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-test-123',
          item_id: 'item-sandbox-test-456',
          request_id: 'req-123'
        }.to_json
      )

    # Mock Plaid institutions get by id (for logo)
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: {
            institution_id: 'ins_1',
            name: 'Test Bank',
            logo: VALID_PNG_BASE64
          },
          request_id: 'req-456'
        }.to_json
      )

    # Mock Plaid accounts get
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [
            {
              account_id: 'acc-checking-123',
              name: 'Checking Account',
              official_name: 'Primary Checking',
              mask: '1234',
              type: 'depository',
              subtype: 'checking',
              balances: {
                available: 1000.00,
                current: 1050.00
              }
            },
            {
              account_id: 'acc-savings-456',
              name: 'Savings Account',
              official_name: 'Primary Savings',
              mask: '5678',
              type: 'depository',
              subtype: 'savings',
              balances: {
                available: 5000.00,
                current: 5000.00
              }
            }
          ],
          request_id: 'req-789'
        }.to_json
      )

    assert_difference 'Bank.count', 1 do
      assert_difference 'BankAccount.count', 2 do
        post banks_path, params: {
          public_token: 'public-sandbox-token',
          institution_id: 'ins_1',
          institution_name: 'Test Bank'
        }
      end
    end

    assert_redirected_to settings_path
    assert_equal 'Bank account linked successfully.', flash[:notice]

    # Verify bank was created correctly
    bank = Bank.find_by(plaid_item_id: 'item-sandbox-test-456')
    assert_equal user_without_bank.id, bank.user_id
    assert_equal 'Test Bank', bank.name
    assert_equal 'item-sandbox-test-456', bank.plaid_item_id
    assert_equal 'access-sandbox-test-123', bank.plaid_access_token
    assert_equal 'ins_1', bank.plaid_institution_id
    assert_equal VALID_PNG_BASE64, bank.logo

    # Verify accounts were created correctly
    checking = bank.bank_accounts.find_by(plaid_account_id: 'acc-checking-123')
    assert_not_nil checking
    assert_equal 'Checking Account', checking.name
    assert_equal '1234', checking.masked_account_number
    assert_equal 'depository', checking.account_type
    assert_equal 'checking', checking.account_subtype
    assert_equal 1000.00, checking.available_balance
    assert_equal 1050.00, checking.current_balance

    savings = bank.bank_accounts.find_by(plaid_account_id: 'acc-savings-456')
    assert_not_nil savings
    assert_equal 'Savings Account', savings.name
  end

  test 'create succeeds without logo when institution fetch fails' do
    user_without_bank = User.create!(
      first_name: 'NoLogo',
      last_name: 'User',
      email_address: 'nologo@example.com',
      password: 'password'
    )
    sign_in_as(user_without_bank)

    # Mock Plaid token exchange
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-nologo',
          item_id: 'item-sandbox-nologo',
          request_id: 'req-123'
        }.to_json
      )

    # Mock Plaid institutions get by id - FAILS
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_INSTITUTION',
          error_message: 'Institution not found'
        }.to_json
      )

    # Mock Plaid accounts get
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [
            {
              account_id: 'acc-nologo-123',
              name: 'Checking',
              mask: '1234',
              type: 'depository',
              subtype: 'checking',
              balances: { available: 100.00, current: 100.00 }
            }
          ],
          request_id: 'req-789'
        }.to_json
      )

    assert_difference 'Bank.count', 1 do
      post banks_path, params: {
        public_token: 'public-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      }
    end

    assert_redirected_to settings_path
    assert_equal 'Bank account linked successfully.', flash[:notice]

    bank = Bank.find_by(plaid_item_id: 'item-sandbox-nologo')
    assert_nil bank.logo
  end

  test 'create fails when user already has a bank and cleans up Plaid item' do
    # johndoe already has a bank from fixtures
    sign_in_as(@user)

    # Mock Plaid token exchange
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-duplicate',
          item_id: 'item-sandbox-duplicate',
          request_id: 'req-123'
        }.to_json
      )

    # Mock Plaid institutions get by id
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: { institution_id: 'ins_1', name: 'Test Bank', logo: nil },
          request_id: 'req-456'
        }.to_json
      )

    # Mock Plaid accounts get
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [
            {
              account_id: 'acc-dup-123',
              name: 'Checking',
              mask: '1234',
              type: 'depository',
              subtype: 'checking',
              balances: { available: 100.00, current: 100.00 }
            }
          ],
          request_id: 'req-789'
        }.to_json
      )

    # Mock Plaid item remove (cleanup after failed save)
    remove_stub = stub_request(:post, 'https://sandbox.plaid.com/item/remove')
                  .to_return(
                    status: 200,
                    headers: { 'Content-Type' => 'application/json' },
                    body: { request_id: 'req-remove' }.to_json
                  )

    assert_no_difference 'Bank.count' do
      post banks_path, params: {
        public_token: 'public-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      }
    end

    assert_redirected_to settings_path
    assert_equal 'Failed to link bank account. Please try again.', flash[:alert]
    assert_requested remove_stub
  end

  test 'create requires authentication' do
    post banks_path, params: { public_token: 'test-token' }

    assert_redirected_to new_session_path
  end

  test 'create redirects with error on Plaid API failure' do
    sign_in_as(@user)

    # Mock Plaid token exchange failure
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

    post banks_path, params: {
      public_token: 'invalid-token',
      institution_id: 'ins_1',
      institution_name: 'Test Bank'
    }

    assert_redirected_to settings_path
    assert_equal 'Failed to link bank account. Please try again.', flash[:alert]
  end

  test 'create cleans up Plaid item when accounts_get fails after token exchange' do
    user_without_bank = User.create!(
      first_name: 'AccountsFail',
      last_name: 'User',
      email_address: 'accountsfail@example.com',
      password: 'password'
    )
    sign_in_as(user_without_bank)

    # Mock Plaid token exchange - succeeds
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-accounts-fail',
          item_id: 'item-sandbox-accounts-fail',
          request_id: 'req-123'
        }.to_json
      )

    # Mock Plaid institutions get by id - succeeds
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: { institution_id: 'ins_1', name: 'Test Bank', logo: nil },
          request_id: 'req-456'
        }.to_json
      )

    # Mock Plaid accounts get - FAILS
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

    # Mock Plaid item remove - should be called to clean up
    remove_stub = stub_request(:post, 'https://sandbox.plaid.com/item/remove')
                  .to_return(
                    status: 200,
                    headers: { 'Content-Type' => 'application/json' },
                    body: { request_id: 'req-remove' }.to_json
                  )

    assert_no_difference 'Bank.count' do
      post banks_path, params: {
        public_token: 'public-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      }
    end

    assert_redirected_to settings_path
    assert_equal 'Failed to link bank account. Please try again.', flash[:alert]
    assert_requested remove_stub
  end

  test 'create cleans up Plaid item when no accounts returned' do
    user_without_bank = User.create!(
      first_name: 'NoAccounts',
      last_name: 'User',
      email_address: 'noaccounts@example.com',
      password: 'password'
    )
    sign_in_as(user_without_bank)

    # Mock Plaid token exchange - succeeds
    stub_request(:post, 'https://sandbox.plaid.com/item/public_token/exchange')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          access_token: 'access-sandbox-no-accounts',
          item_id: 'item-sandbox-no-accounts',
          request_id: 'req-123'
        }.to_json
      )

    # Mock Plaid institutions get by id - succeeds
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: { institution_id: 'ins_1', name: 'Test Bank', logo: nil },
          request_id: 'req-456'
        }.to_json
      )

    # Mock Plaid accounts get - returns empty array
    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [],
          request_id: 'req-789'
        }.to_json
      )

    # Mock Plaid item remove - should be called to clean up
    remove_stub = stub_request(:post, 'https://sandbox.plaid.com/item/remove')
                  .to_return(
                    status: 200,
                    headers: { 'Content-Type' => 'application/json' },
                    body: { request_id: 'req-remove' }.to_json
                  )

    assert_no_difference 'Bank.count' do
      post banks_path, params: {
        public_token: 'public-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      }
    end

    assert_redirected_to settings_path
    assert_equal 'No accounts found at this institution. Please try a different bank.', flash[:alert]
    assert_requested remove_stub
  end

  test 'destroy requires authentication' do
    bank = banks(:chase)

    delete bank_path(bank)

    assert_redirected_to new_session_path
  end

  test 'destroy removes bank and redirects' do
    # Mock Plaid item remove (called on destroy callback)
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { request_id: 'req-remove' }.to_json
      )

    # Create a user with a bank for this test
    user = User.create!(
      first_name: 'Destroy',
      last_name: 'User',
      email_address: 'destroyuser@example.com',
      password: 'password'
    )
    bank = Bank.create!(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_destroy_test',
      plaid_access_token: 'access_token_destroy_test',
      plaid_institution_id: 'ins_1',
      plaid_institution_name: 'Test Institution'
    )
    sign_in_as(user)

    assert_difference('Bank.count', -1) do
      delete bank_path(bank)
    end

    assert_redirected_to settings_path
    assert_equal 'Bank account deleted successfully.', flash[:notice]
  end

  test 'destroy fails gracefully when Plaid API fails' do
    # Mock Plaid item remove failure
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_ACCESS_TOKEN',
          error_message: 'The access token is invalid'
        }.to_json
      )

    # Create a user with a bank for this test
    user = User.create!(
      first_name: 'DestroyFail',
      last_name: 'User',
      email_address: 'destroyfailuser@example.com',
      password: 'password'
    )
    bank = Bank.create!(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_destroy_fail_test',
      plaid_access_token: 'access_token_destroy_fail_test',
      plaid_institution_id: 'ins_1',
      plaid_institution_name: 'Test Institution'
    )
    sign_in_as(user)

    assert_no_difference('Bank.count') do
      delete bank_path(bank)
    end

    assert_redirected_to settings_path
    assert_equal 'Failed to unlink from Plaid. Please try again.', flash[:alert]
  end

  test 'destroy cannot delete another users bank' do
    # Create two users with banks
    user1 = User.create!(
      first_name: 'User',
      last_name: 'One',
      email_address: 'userone@example.com',
      password: 'password'
    )
    user2 = User.create!(
      first_name: 'User',
      last_name: 'Two',
      email_address: 'usertwo@example.com',
      password: 'password'
    )
    Bank.create!(
      user: user1,
      name: 'User One Bank',
      plaid_item_id: 'item_user_one',
      plaid_access_token: 'access_token_user_one',
      plaid_institution_id: 'ins_1',
      plaid_institution_name: 'Bank One'
    )
    other_user_bank = Bank.create!(
      user: user2,
      name: 'User Two Bank',
      plaid_item_id: 'item_user_two',
      plaid_access_token: 'access_token_user_two',
      plaid_institution_id: 'ins_2',
      plaid_institution_name: 'Bank Two'
    )

    # Sign in as user1 but try to delete user2's bank
    sign_in_as(user1)

    assert_no_difference('Bank.count') do
      delete bank_path(other_user_bank)
    end

    assert_response :not_found
  end
end
