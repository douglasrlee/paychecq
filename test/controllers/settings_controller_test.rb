require 'test_helper'

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'show requires authentication' do
    get settings_path

    assert_redirected_to new_session_path
  end

  test 'show' do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']
  end

  test 'show displays linked bank' do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    # johndoe has Chase bank from fixtures
    assert_select 'span', text: 'Chase'
  end

  test 'show displays error alert when bank has error status' do
    user = create_user_with_bank(email: 'errorstatus@example.com', plaid_item_id: 'item_error_status', status: 'error', plaid_error_code: 'ITEM_LOGIN_REQUIRED')
    sign_in_as(user)

    stub_request(:post, 'https://sandbox.plaid.com/link/token/create')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          link_token: 'link-update-token',
          expiration: 1.hour.from_now.iso8601,
          request_id: 'req-1'
        }.to_json
      )

    get settings_path

    assert_response :success
    assert_select '.alert-error', text: /Connection Error/
    assert_select 'button', text: /Reconnect/
  end

  test 'show displays warning alert when bank has pending_expiration status' do
    user = create_user_with_bank(email: 'pendingstatus@example.com', plaid_item_id: 'item_pending_status', status: 'pending_expiration')
    sign_in_as(user)

    stub_request(:post, 'https://sandbox.plaid.com/link/token/create')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          link_token: 'link-update-token',
          expiration: 1.hour.from_now.iso8601,
          request_id: 'req-1'
        }.to_json
      )

    get settings_path

    assert_response :success
    assert_select '.alert-warning', text: /Consent Expiring Soon/
    assert_select 'button', text: /Re-authorize/
  end

  test 'show displays disconnected alert without reconnect button' do
    user = create_user_with_bank(email: 'disconnected@example.com', plaid_item_id: 'item_disconnected', status: 'disconnected')
    sign_in_as(user)

    get settings_path

    assert_response :success
    assert_select '.alert-error', text: /Account Disconnected/
    assert_select 'button', text: /Reconnect/, count: 0
    assert_select 'button', text: /Re-authorize/, count: 0
  end

  test 'show does not display alert when bank is healthy' do
    sign_in_as(@user)

    get settings_path

    assert_response :success
    assert_select '.alert-error', count: 0
    assert_select '.alert-warning', count: 0
  end

  test 'show displays empty state when no banks linked' do
    # Mock Plaid link token creation
    stub_request(:post, 'https://sandbox.plaid.com/link/token/create')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          link_token: 'link-sandbox-test-token',
          expiration: 1.hour.from_now.iso8601,
          request_id: 'req-link-token'
        }.to_json
      )

    user_without_banks = User.create!(
      first_name: 'No',
      last_name: 'Banks',
      email_address: 'nobanks@example.com',
      password: 'password'
    )
    sign_in_as(user_without_banks)

    get settings_path

    assert_response :success
    assert_select 'p', text: 'No linked account yet'
  end

  private

  def create_user_with_bank(email:, plaid_item_id:, status: 'healthy', plaid_error_code: nil)
    user = User.create!(first_name: 'Status', last_name: 'Test', email_address: email, password: 'password')

    Bank.create!(
      user: user,
      name: 'Test Bank',
      plaid_item_id: plaid_item_id,
      plaid_access_token: 'access_token_test',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank',
      status: status,
      plaid_error_code: plaid_error_code
    )

    user
  end
end
