require 'application_system_test_case'

class SessionsTest < ApplicationSystemTestCase
  test 'user can sign in with valid credentials' do
    user = users(:johndoe)

    visit new_session_path

    fill_in 'email_address', with: user.email_address
    fill_in 'password', with: 'password'
    click_button 'Sign in'

    assert_text 'Transactions'
  end

  test 'user cannot sign in with invalid credentials' do
    visit new_session_path

    fill_in 'email_address', with: 'wrong@example.com'
    fill_in 'password', with: 'wrongpassword'
    click_button 'Sign in'

    assert_text 'Try another email address or password.'
  end
end
