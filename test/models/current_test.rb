require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  def setup
    Current.reset
  end

  def teardown
    Current.reset
  end

  test "has a session attribute that can be assigned and read" do
    user = users(:john)
    session = Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "Test UA")

    assert_nil Current.session

    Current.session = session

    assert_equal session, Current.session
  end

  test "delegates user to the session (when present)" do
    user = users(:john)
    session = Session.create!(user: user, ip_address: "127.0.0.2", user_agent: "Test UA 2")

    Current.session = session

    assert_equal user, Current.user
  end

  test "delegated user returns nil when there is no session" do
    Current.session = nil

    assert_nil Current.user
  end
end
