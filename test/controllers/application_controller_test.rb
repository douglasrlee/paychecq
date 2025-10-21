require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  class TestAppOpenController < ApplicationController
    allow_unauthenticated_access only: :show

    prepend_before_action :sign_in_from_param

    def show
      render json: {
        current_user_id: current_user&.id,
        whodunnit: PaperTrail.request.whodunnit
      }
    end

    private
      def sign_in_from_param
        if params[:as_user_id].present?
          user = User.find(params[:as_user_id])

          Current.session = Session.create!(user: user, ip_address: request.remote_ip, user_agent: request.user_agent)
        end
      end
  end

  class TestAppAuthController < ApplicationController
    def show
      head :ok
    end

    private
      def request_authentication
        redirect_to "/session/new"
      end
  end

  def setup
    @previous_pt_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true
  end

  def teardown
    PaperTrail.enabled = @previous_pt_enabled
    Current.reset
  end

  test "current_user returns Current.user and whodunnit is set when authenticated" do
    user = users(:john)

    with_routing do |set|
      set.draw do
        get "/test_app_open" => "application_controller_test/test_app_open#show"
      end

      get "/test_app_open", params: { as_user_id: user.id }

      assert_response :success

      json = JSON.parse(@response.body)

      assert_equal user.id, json["current_user_id"]
      assert_equal user.id.to_s, json["whodunnit"]
    end
  end

  test "unauthenticated request is redirected to new_session_path" do
    Current.session = nil

    with_routing do |set|
      set.draw do
        get "/test_app_auth" => "application_controller_test/test_app_auth#show"
        resource :session
      end

      get "/test_app_auth"

      assert_response :redirect
      assert_redirected_to new_session_path
    end
  end
end
