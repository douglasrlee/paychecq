require 'test_helper'

class BankServiceTest < ActiveSupport::TestCase
  VALID_PNG_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='.freeze

  setup do
    @user = User.create!(
      first_name: 'Bank',
      last_name: 'Test',
      email_address: "bankservice_#{SecureRandom.hex(4)}@example.com",
      password: 'password'
    )
  end

  test 'link successfully creates bank and accounts' do
    stub_exchange
    stub_institution_logo(VALID_PNG_BASE64)
    stub_accounts

    assert_difference 'Bank.count', 1 do
      assert_difference 'BankAccount.count', 1 do
        result = BankService.link(
          user: @user,
          public_token: 'public-sandbox-token',
          institution_id: 'ins_1',
          institution_name: 'Test Bank'
        )

        assert result.success
        assert_nil result.error
      end
    end

    bank = Bank.find_by(plaid_item_id: 'item-sandbox-456')
    assert_equal @user.id, bank.user_id
    assert_equal 'Test Bank', bank.name
    assert_equal 'access-sandbox-123', bank.plaid_access_token
    assert_equal 'ins_1', bank.plaid_institution_id
    assert_equal VALID_PNG_BASE64, bank.logo

    checking = bank.bank_accounts.find_by(plaid_account_id: 'acc-checking-123')
    assert_equal 'Checking Account', checking.name
    assert_equal 'Primary Checking', checking.official_name
    assert_equal '1234', checking.masked_account_number
    assert_equal 'depository', checking.account_type
    assert_equal 'checking', checking.account_subtype
    assert_equal 1000.00, checking.available_balance
    assert_equal 1050.00, checking.current_balance
  end

  test 'link succeeds without logo when institution fetch fails' do
    stub_exchange
    stub_institution_logo_failure
    stub_accounts

    result = BankService.link(
      user: @user,
      public_token: 'public-sandbox-token',
      institution_id: 'ins_1',
      institution_name: 'Test Bank'
    )

    assert result.success

    bank = Bank.find_by(plaid_item_id: 'item-sandbox-456')
    assert_nil bank.logo
  end

  test 'link returns error and cleans up when no accounts returned' do
    stub_exchange
    stub_institution_logo(nil)
    stub_accounts(accounts: [])
    remove_stub = stub_remove_item

    assert_no_difference 'Bank.count' do
      result = BankService.link(
        user: @user,
        public_token: 'public-sandbox-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      )

      assert_not result.success
      assert_equal 'No accounts found at this institution. Please try a different bank.', result.error
    end

    assert_requested remove_stub
  end

  test 'link returns error on Plaid token exchange failure' do
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

    result = BankService.link(
      user: @user,
      public_token: 'invalid-token',
      institution_id: 'ins_1',
      institution_name: 'Test Bank'
    )

    assert_not result.success
    assert_equal 'Failed to link bank account. Please try again.', result.error
  end

  test 'link returns error and cleans up when accounts fetch fails' do
    stub_exchange
    stub_institution_logo(nil)

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

    remove_stub = stub_remove_item

    assert_no_difference 'Bank.count' do
      result = BankService.link(
        user: @user,
        public_token: 'public-sandbox-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      )

      assert_not result.success
      assert_equal 'Failed to link bank account. Please try again.', result.error
    end

    assert_requested remove_stub
  end

  test 'link returns error and cleans up on record invalid' do
    # Give user an existing bank so uniqueness validation fails
    Bank.create!(
      user: @user,
      name: 'Existing Bank',
      plaid_item_id: 'item-existing',
      plaid_access_token: 'access-existing',
      plaid_institution_id: 'ins_existing',
      plaid_institution_name: 'Existing'
    )

    stub_exchange
    stub_institution_logo(nil)
    stub_accounts
    remove_stub = stub_remove_item

    assert_no_difference 'Bank.count' do
      result = BankService.link(
        user: @user,
        public_token: 'public-sandbox-token',
        institution_id: 'ins_1',
        institution_name: 'Test Bank'
      )

      assert_not result.success
      assert_equal 'Failed to link bank account. Please try again.', result.error
    end

    assert_requested remove_stub
  end

  private

  def stub_exchange
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
  end

  def stub_institution_logo(logo)
    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: { institution_id: 'ins_1', name: 'Test Bank', logo: logo },
          request_id: 'req-456'
        }.to_json
      )
  end

  def stub_institution_logo_failure
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
  end

  def stub_accounts(accounts: nil)
    accounts ||= [
      {
        account_id: 'acc-checking-123',
        name: 'Checking Account',
        official_name: 'Primary Checking',
        mask: '1234',
        type: 'depository',
        subtype: 'checking',
        balances: { available: 1000.00, current: 1050.00 }
      }
    ]

    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { accounts: accounts, request_id: 'req-789' }.to_json
      )
  end

  def stub_remove_item
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { request_id: 'req-remove' }.to_json
      )
  end
end
