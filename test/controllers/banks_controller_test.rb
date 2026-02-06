require 'test_helper'

class BanksControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'create requires authentication' do
    post banks_path, params: { public_token: 'test-token' }

    assert_redirected_to new_session_path
  end

  test 'create redirects with notice on success' do
    user_without_bank = User.create!(
      first_name: 'New',
      last_name: 'User',
      email_address: 'newuser_ctrl@example.com',
      password: 'password'
    )
    sign_in_as(user_without_bank)

    stub_successful_link

    post banks_path, params: {
      public_token: 'public-sandbox-token',
      institution_id: 'ins_1',
      institution_name: 'Test Bank'
    }

    assert_redirected_to settings_path
    assert_equal 'Bank account linked successfully.', flash[:notice]
  end

  test 'create redirects with alert on failure' do
    sign_in_as(@user)

    # Token exchange fails — BankService.link returns error
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

  test 'destroy requires authentication' do
    bank = banks(:chase)

    delete bank_path(bank)

    assert_redirected_to new_session_path
  end

  test 'destroy removes bank and redirects' do
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { request_id: 'req-remove' }.to_json
      )

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

    sign_in_as(user1)

    assert_no_difference('Bank.count') do
      delete bank_path(other_user_bank)
    end

    assert_response :not_found
  end

  private

  def stub_successful_link
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

    stub_request(:post, 'https://sandbox.plaid.com/institutions/get_by_id')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          institution: { institution_id: 'ins_1', name: 'Test Bank', logo: nil },
          request_id: 'req-456'
        }.to_json
      )

    stub_request(:post, 'https://sandbox.plaid.com/accounts/get')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          accounts: [
            {
              account_id: "acc-ctrl-#{SecureRandom.hex(4)}",
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
  end
end
