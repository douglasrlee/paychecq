require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "is valid with a user and optional attributes" do
    user = users(:john)

    session = Session.new(user: user, ip_address: "127.0.0.1", user_agent: "Test UA")

    assert session.valid?, session.errors.full_messages.to_s
    assert session.save!

    assert_equal user, session.user
    assert_includes user.sessions, session
  end

  test "is invalid without a user and has correct error message" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "UA")

    assert_not session.valid?, "Session should be invalid without a user"
    assert_includes session.errors.attribute_names, :user
    assert_includes session.errors[:user], "must exist"

    assert_raises(ActiveRecord::RecordInvalid) { session.save! }
  end

  test "ip_address and user_agent are optional" do
    user = users(:jane)

    session = Session.new(user: user)
    assert session.valid?, session.errors.full_messages.to_s
    assert_difference -> { Session.count }, +1 do
      session.save!
    end

    session.reload
    assert_nil session.ip_address
    assert_nil session.user_agent
  end
end
