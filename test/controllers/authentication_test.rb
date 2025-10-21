require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  class AuthTestController < ActionController::Base
    include Authentication

    allow_unauthenticated_access only: [ :public_action, :login, :set_return_to, :next_url ]

    def protected_action
      render json: { ok: true, current_user_id: Current.user&.id }
    end

    def public_action
      render json: { ok: true }
    end

    def login
      user = User.find(params.require(:user_id))

      start_new_session_for(user)

      render json: { session_id: Current.session.id }
    end

    def logout
      terminate_session

      head :ok
    end

    def set_return_to
      session[:return_to_after_authenticating] = params.require(:url)

      head :ok
    end

    def next_url
      render json: { url: after_authentication_url }
    end

    private
      def root_url
        "http://example.com/"
      end
  end

  def setup
    @user = users(:john)
  end

  test "protected action redirects to new_session_path when unauthenticated" do
    with_routing do |set|
      set.draw do
        get "/auth_test/protected" => "authentication_test/auth_test#protected_action"

        resource :session
      end

      get "/auth_test/protected"

      assert_response :redirect
      assert_redirected_to new_session_path
    end
  end

  test "public action is accessible without authentication via allow_unauthenticated_access" do
    with_routing do |set|
      set.draw do
        get "/auth_test/public" => "authentication_test/auth_test#public_action"
      end

      get "/auth_test/public"

      assert_response :success

      json = JSON.parse(@response.body)

      assert_equal true, json["ok"]
    end
  end

  test "login starts a new session, sets cookie, and allows subsequent protected access" do
    with_routing do |set|
      set.draw do
        get "/auth_test/login" => "authentication_test/auth_test#login"
        get "/auth_test/protected" => "authentication_test/auth_test#protected_action"
        get "/auth_test/logout" => "authentication_test/auth_test#logout"

        resource :session
      end

      assert_difference -> { Session.count }, +1 do
        get "/auth_test/login", params: { user_id: @user.id }
      end
      assert_response :success

      login_json = JSON.parse(@response.body)
      created_session_id = login_json["session_id"]

      assert_not_nil created_session_id
      assert Session.find_by(id: created_session_id), "Session should exist after login"

      get "/auth_test/protected"

      assert_response :success

      protected_json = JSON.parse(@response.body)

      assert_equal @user.id, protected_json["current_user_id"]
      assert_difference -> { Session.where(id: created_session_id).count }, -1 do
        get "/auth_test/logout"
      end
      assert_response :success

      get "/auth_test/protected"

      assert_response :redirect
      assert_redirected_to new_session_path
    end
  end

  test "after_authentication_url returns and clears stored return_to location" do
    with_routing do |set|
      set.draw do
        get "/auth_test/set_return_to" => "authentication_test/auth_test#set_return_to"
        get "/auth_test/next_url" => "authentication_test/auth_test#next_url"
      end

      desired = "http://example.com/some/path?param=1"

      get "/auth_test/set_return_to", params: { url: desired }

      assert_response :success

      get "/auth_test/next_url"

      assert_response :success

      json = JSON.parse(@response.body)
      assert_equal desired, json["url"]

      get "/auth_test/next_url"

      assert_response :success

      json2 = JSON.parse(@response.body)

      assert_equal "http://example.com/", json2["url"]
    end
  end
end
