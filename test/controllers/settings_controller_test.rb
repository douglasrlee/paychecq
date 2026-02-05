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

  test 'show displays empty state when no banks linked' do
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
