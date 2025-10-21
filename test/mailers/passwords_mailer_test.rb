require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  def setup
    @user = users(:john)
  end

  test "reset email has correct subject and recipient" do
    mail = PasswordsMailer.reset(@user)

    assert_equal "Reset your password", mail.subject
    assert_equal [ @user.email ], mail.to
  end

  test "reset email includes a password reset link in both text and html parts and they match" do
    mail = PasswordsMailer.reset(@user)

    assert mail.multipart?, "Expected multipart email with text and HTML"

    parts = mail.parts.index_by { |p| p.content_type.to_s.split(";").first }

    assert parts.key?("text/plain"), "Expected a text/plain part"
    assert parts.key?("text/html"), "Expected a text/html part"

    text_body = parts["text/plain"].body.decoded
    html_body = parts["text/html"].body.decoded

    text_token = text_body[%r{passwords/([^/\s]+)/edit}, 1]
    html_token = html_body[%r{passwords/([^"/]+)/edit}, 1]

    assert_not_nil text_token, "Expected a reset URL with token in text part"
    assert_not_nil html_token, "Expected a reset URL with token in HTML part"

    expected_prefix = "http://example.com/passwords/"

    assert_includes text_body, expected_prefix
    assert_includes html_body, expected_prefix

    if User.respond_to?(:find_by_password_reset_token!)
      assert_equal @user, User.find_by_password_reset_token!(text_token)
      assert_equal @user, User.find_by_password_reset_token!(html_token)
    end
  end

  test "deliver_later enqueues the email" do
    assert_enqueued_emails 1 do
      PasswordsMailer.reset(@user).deliver_later
    end
  end
end
