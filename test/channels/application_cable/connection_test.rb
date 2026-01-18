require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid session" do
    user = users(:johndoe)
    session = user.sessions.create!

    cookies.signed[:session_id] = session.id

    connect

    assert_equal user, connection.current_user
  end

  test "rejects connection without session" do
    assert_reject_connection { connect }
  end

  test "rejects connection with invalid session" do
    cookies.signed[:session_id] = "invalid"

    assert_reject_connection { connect }
  end
end
