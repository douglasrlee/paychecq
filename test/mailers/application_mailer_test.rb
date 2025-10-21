require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "has default from address configured" do
    assert_equal "from@example.com", ApplicationMailer.default_params[:from]
  end

  test "uses the mailer layout" do
    assert_equal "mailer", ApplicationMailer._layout.to_s
  end

  test "child mailers inherit default from and render with layout" do
    user = users(:john)

    email = PasswordsMailer.reset(user)

    assert_equal [ "from@example.com" ], email.from
    assert email.text_part, "Expected a text part to be present"
    assert email.html_part, "Expected an HTML part to be present"

    html = email.html_part.body.to_s

    assert_includes html, "<!DOCTYPE html>"
    assert_includes html, "<html"
    assert_includes html, "</html>"
    assert_includes html, "password reset"
  end
end
