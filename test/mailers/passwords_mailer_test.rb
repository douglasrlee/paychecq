require 'test_helper'

class PasswordsMailerTest < ActionMailer::TestCase
  test 'reset' do
    user = users(:johndoe)
    mail = PasswordsMailer.reset(user)

    assert_equal 'Reset your password', mail.subject
    assert_equal [ user.email_address ], mail.to
  end
end
