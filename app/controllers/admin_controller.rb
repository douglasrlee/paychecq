class AdminController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    redirect_to main_app.root_path, alert: 'Not authorized' unless Current.user&.admin?
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url

    redirect_to main_app.new_session_path
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || main_app.root_url
  end
end
