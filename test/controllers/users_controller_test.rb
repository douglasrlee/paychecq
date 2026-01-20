require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_user_path

    assert_response :success
  end

  test 'create with valid params' do
    assert_difference([ 'User.count', 'Session.count' ]) do
      post users_path, params: {
        user: {
          first_name: 'Test',
          last_name: 'User',
          email_address: 'newuser@example.com',
          password: 'password',
          password_confirmation: 'password'
        }
      }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test 'create with invalid params' do
    assert_no_difference('User.count') do
      post users_path, params: {
        user: {
          first_name: '',
          last_name: '',
          email_address: '',
          password: '',
          password_confirmation: ''
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test 'create with mismatched passwords' do
    assert_no_difference('User.count') do
      post users_path, params: {
        user: {
          first_name: 'Test',
          last_name: 'User',
          email_address: 'newuser@example.com',
          password: 'password',
          password_confirmation: 'different'
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
