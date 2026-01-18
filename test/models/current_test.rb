require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup { Current.reset }
  teardown { Current.reset }

  test "session attribute can be set and read" do
    session = users(:johndoe).sessions.create!

    Current.session = session

    assert_equal session, Current.session
  end

  test "user delegates to session" do
    user = users(:johndoe)
    session = user.sessions.create!

    Current.session = session

    assert_equal user, Current.user
  end

  test "user returns nil when session is nil" do
    Current.session = nil

    assert_nil Current.user
  end
end
