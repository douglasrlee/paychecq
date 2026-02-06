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
    bank = create_bank(email: 'errorstatus@example.com', plaid_item_id: 'item_error_status', status: 'error', plaid_error_code: 'ITEM_LOGIN_REQUIRED')
    sign_in_as(bank.user)

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
    bank = create_bank(email: 'pendingstatus@example.com', plaid_item_id: 'item_pending_status', status: 'pending_expiration')
    sign_in_as(bank.user)

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
    bank = create_bank(email: 'disconnected@example.com', plaid_item_id: 'item_disconnected', status: 'disconnected')
    sign_in_as(bank.user)

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

  test 'show displays flash alert when update link token creation fails' do
    bank = create_bank(email: 'tokenfail@example.com', plaid_item_id: 'item_token_fail', status: 'error', plaid_error_code: 'ITEM_LOGIN_REQUIRED')
    sign_in_as(bank.user)

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

    get settings_path

    assert_response :success
    assert_select '.alert-error', text: /Connection Error/
    assert_select 'button', text: /Reconnect/, count: 0
    assert_equal 'Unable to initialize bank reconnection. Please try again later.', flash[:alert]
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
end
