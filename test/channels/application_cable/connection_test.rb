require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def setup
    @user = users(:john)
    @session = Session.create!(user: @user, ip_address: "127.0.0.1", user_agent: "Cable Test")
  end

  test "connects with a valid signed session cookie and sets current_user" do
    cookies.signed[:session_id] = @session.id

    connect

    assert_equal @user, connection.current_user
  end

  test "rejects connection when no session cookie is present" do
    assert_reject_connection { connect }
  end

  test "rejects connection when session cookie is invalid" do
    cookies.signed[:session_id] = SecureRandom.uuid

    assert_reject_connection { connect }
  end
end
