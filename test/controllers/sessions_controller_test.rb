require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test 'new' do
    get new_session_path

    assert_response :success
  end

  test 'create with valid credentials' do
    post session_path, params: { email_address: @user.email_address, password: 'password' }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test 'redirects to original url after login' do
    get transactions_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: 'password' }
    assert_redirected_to transactions_path
  end

  test 'create with invalid credentials' do
    post session_path, params: { email_address: @user.email_address, password: 'wrong' }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test 'destroy' do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
