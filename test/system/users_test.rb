require 'application_system_test_case'

class UsersTest < ApplicationSystemTestCase
  test 'user can create an account' do
    visit new_user_path

    fill_in 'user_first_name', with: 'Test'
    fill_in 'user_last_name', with: 'User'
    fill_in 'user_email_address', with: 'newuser@example.com'
    fill_in 'user_password', with: 'password123'
    fill_in 'user_password_confirmation', with: 'password123'
    click_button 'Create account'

    assert_text 'Transactions'
  end

  test 'user cannot create an account with mismatched passwords' do
    visit new_user_path

    fill_in 'user_first_name', with: 'Test'
    fill_in 'user_last_name', with: 'User'
    fill_in 'user_email_address', with: 'newuser@example.com'
    fill_in 'user_password', with: 'password123'
    fill_in 'user_password_confirmation', with: 'different'
    click_button 'Create account'

    assert_text "Password confirmation doesn't match Password"
  end

  test 'user cannot create an account with an existing email' do
    existing_user = users(:johndoe)

    visit new_user_path

    fill_in 'user_first_name', with: 'Test'
    fill_in 'user_last_name', with: 'User'
    fill_in 'user_email_address', with: existing_user.email_address
    fill_in 'user_password', with: 'password123'
    fill_in 'user_password_confirmation', with: 'password123'
    click_button 'Create account'

    assert_text 'Email address has already been taken'
  end
end
