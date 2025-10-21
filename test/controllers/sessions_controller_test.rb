require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
  end

  test "GET new renders successfully" do
    get new_session_path

    assert_response :success
  end

  test "POST create with valid credentials creates session, sets cookie, and redirects to root" do
    open_session do |session|
      assert_difference -> { Session.count }, +1 do
        session.post session_path, params: { email: @user.email, password: "password" }
      end

      session.assert_response :redirect
      session.assert_redirected_to "http://www.example.com/"

      assert_not_nil session.cookies["session_id"], "Expected session_id cookie to be set"

      created = Session.order(:created_at).last

      assert_equal @user, created.user
    end
  end

  test "POST create with invalid credentials redirects back with alert and does not create session" do
    assert_no_difference -> { Session.count } do
      post session_path, params: { email: @user.email, password: "wrong" }
    end

    assert_response :redirect
    assert_redirected_to new_session_path

    assert_equal "Try another email address or password.", flash[:alert]

    assert_nil cookies["session_id"], "Did not expect session_id cookie to be set"
  end

  test "DELETE destroy terminates session, clears cookie, and redirects to new" do
    open_session do |session|
      assert_difference -> { Session.count }, +1 do
        session.post session_path, params: { email: @user.email, password: "password" }
      end
      session.assert_response :redirect

      created = Session.order(:created_at).last

      assert_difference -> { Session.where(id: created.id).count }, -1 do
        session.delete session_path
      end

      session.assert_response :redirect
      session.assert_redirected_to new_session_path

      cleared = session.cookies["session_id"]

      assert cleared.nil? || cleared == "", "Expected session_id cookie to be cleared"
    end
  end
end
