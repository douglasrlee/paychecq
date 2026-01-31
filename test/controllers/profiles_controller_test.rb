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
        last_name: 'Name'
      }
    }

    assert_redirected_to profile_path
    @user.reload
    assert_equal 'Updated', @user.first_name
    assert_equal 'Name', @user.last_name
  end

  test 'update with invalid params' do
    sign_in_as(@user)

    patch profile_path, params: {
      user: {
        first_name: '',
        last_name: ''
      }
    }

    assert_response :unprocessable_entity
  end

  test 'edit_security requires authentication' do
    get edit_security_profile_path

    assert_redirected_to new_session_path
  end

  test 'edit_security' do
    sign_in_as(@user)

    get edit_security_profile_path

    assert_response :success
  end

  test 'update_security email with correct current password' do
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: 'newemail@example.com',
        password: '',
        password_confirmation: ''
      }
    }

    assert_redirected_to profile_path
    @user.reload
    assert_equal 'newemail@example.com', @user.email_address
  end

  test 'update_security password with correct current password' do
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: @user.email_address,
        password: 'newpassword',
        password_confirmation: 'newpassword'
      }
    }

    assert_redirected_to profile_path
    @user.reload
    assert @user.authenticate('newpassword')
  end

  test 'update_security email and password with correct current password' do
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: 'newemail@example.com',
        password: 'newpassword',
        password_confirmation: 'newpassword'
      }
    }

    assert_redirected_to profile_path
    @user.reload
    assert_equal 'newemail@example.com', @user.email_address
    assert @user.authenticate('newpassword')
  end

  test 'update_security with incorrect current password' do
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'wrongpassword',
        email_address: 'newemail@example.com',
        password: '',
        password_confirmation: ''
      }
    }

    assert_response :unprocessable_entity
  end

  test 'update_security with mismatched passwords' do
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: @user.email_address,
        password: 'newpassword',
        password_confirmation: 'differentpassword'
      }
    }

    assert_response :unprocessable_entity
  end

  test 'update_security password invalidates other sessions' do
    @user.sessions.create!
    other_session = @user.sessions.create!
    sign_in_as(@user)

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: @user.email_address,
        password: 'newpassword',
        password_confirmation: 'newpassword'
      }
    }

    assert_redirected_to profile_path
    assert Session.exists?(Current.session.id)
    assert_not Session.exists?(other_session.id)
  end

  test 'update_security email does not invalidate other sessions' do
    sign_in_as(@user)
    other_session = @user.sessions.create!

    patch update_security_profile_path, params: {
      login: {
        current_password: 'password',
        email_address: 'newemail@example.com',
        password: '',
        password_confirmation: ''
      }
    }

    assert_redirected_to profile_path
    assert Session.exists?(other_session.id)
  end
end
