require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'show requires authentication' do
    get profile_path

    assert_redirected_to new_session_path
  end

  test 'show' do
    sign_in_as(@user)

    get profile_path

    assert_response :success
  end

  test 'edit requires authentication' do
    get edit_profile_path

    assert_redirected_to new_session_path
  end

  test 'edit' do
    sign_in_as(@user)

    get edit_profile_path

    assert_response :success
  end

  test 'update with valid params' do
    sign_in_as(@user)

    patch profile_path, params: {
      user: {
        first_name: 'Updated',
        last_name: 'Name',
        email_address: 'updated@example.com'
      }
    }

    assert_redirected_to profile_path
    @user.reload
    assert_equal 'Updated', @user.first_name
    assert_equal 'Name', @user.last_name
    assert_equal 'updated@example.com', @user.email_address
  end

  test 'update with invalid params' do
    sign_in_as(@user)

    patch profile_path, params: {
      user: {
        first_name: '',
        last_name: '',
        email_address: ''
      }
    }

    assert_response :unprocessable_entity
  end

  test 'edit_password requires authentication' do
    get edit_password_profile_path

    assert_redirected_to new_session_path
  end

  test 'edit_password' do
    sign_in_as(@user)

    get edit_password_profile_path

    assert_response :success
  end

  test 'update_password with correct current password' do
    sign_in_as(@user)

    patch update_password_profile_path, params: {
      current_password: 'password',
      password: 'newpassword',
      password_confirmation: 'newpassword'
    }

    assert_redirected_to profile_path
    @user.reload
    assert @user.authenticate('newpassword')
  end

  test 'update_password with incorrect current password' do
    sign_in_as(@user)

    patch update_password_profile_path, params: {
      current_password: 'wrongpassword',
      password: 'newpassword',
      password_confirmation: 'newpassword'
    }

    assert_response :unprocessable_entity
  end

  test 'update_password with mismatched passwords' do
    sign_in_as(@user)

    patch update_password_profile_path, params: {
      current_password: 'password',
      password: 'newpassword',
      password_confirmation: 'differentpassword'
    }

    assert_response :unprocessable_entity
  end
end
