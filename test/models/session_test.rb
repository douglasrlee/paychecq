require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "is valid with a user" do
    session = Session.new(user: User.take)

    assert session.valid?
  end

  test "is invalid without a user" do
    session = Session.new(user: nil)

    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"
  end
end
