# frozen_string_literal: true

require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'should redirect to sign in page after inactive sign up' do
    post user_registration_path, params: {
      user: {
        name: 'John Doe',
        email: 'johndoe@example.com',
        password: 'P@ssw0rd!',
        password_confirmation: 'P@ssw0rd!'
      }
    }

    assert_redirected_to new_user_session_path
  end
end
