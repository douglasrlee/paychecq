require "test_helper"
require "ostruct"
require "minitest/mock"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
  end

  test "GET new renders successfully" do
    get new_password_path

    assert_response :success
  end

  test "POST create with unknown email redirects and does not call mailer" do
    called = false

    PasswordsMailer.stub(:reset, ->(u) { called = true; OpenStruct.new(deliver_later: true) }) do
      post passwords_path, params: { email: "doesnotexist@example.com" }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
    assert_equal false, called, "Mailer should not be called when email is unknown"
  end

  test "POST create with existing email redirects and calls mailer deliver_later" do
    called_with = nil
    mail_double = OpenStruct.new(deliver_later: true)

    PasswordsMailer.stub(:reset, ->(u) { called_with = u; mail_double }) do
      post passwords_path, params: { email: @user.email }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
    assert_equal @user, called_with, "Mailer should be called with the found user"
  end

  test "GET edit with invalid token redirects to new with alert" do
    User.stub(:find_by_password_reset_token!, ->(_token) { raise ActiveSupport::MessageVerifier::InvalidSignature }) do
      get edit_password_path("bad-token")
    end

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "GET edit with valid token renders successfully" do
    User.stub(:find_by_password_reset_token!, ->(_token) { @user }) do
      get edit_password_path("good-token")

      assert_response :success
    end
  end

  test "PATCH update with valid token and matching passwords resets password and redirects with notice" do
    token = "good-token"

    User.stub(:find_by_password_reset_token!, ->(_token) { @user }) do
      patch password_path(token), params: { token: token, password: "newsecret", password_confirmation: "newsecret" }

      assert_redirected_to new_session_path
      assert_equal "Password has been reset.", flash[:notice]
    end

    @user.reload
    assert @user.authenticate("newsecret"), "Expected user to authenticate with the new password"
  end

  test "PATCH update with mismatched confirmation redirects back with alert" do
    token = "good-token"

    User.stub(:find_by_password_reset_token!, ->(_token) { @user }) do
      patch password_path(token), params: { token: token, password: "newsecret", password_confirmation: "different" }

      assert_redirected_to edit_password_path(token)
      assert_equal "Passwords did not match.", flash[:alert]
    end
  end
end
