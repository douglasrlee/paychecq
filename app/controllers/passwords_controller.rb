class PasswordsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_user_by_token, only: [ :edit, :update ]

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: 'Try again later.' }

  def new; end

  def edit; end

  def create
    if params[:email_address].blank?
      redirect_to new_password_path, alert: 'Email address required.'
    else
      if (user = User.find_by(email_address: params[:email_address]))
        PasswordsMailer.reset(user).deliver_later
      end

      redirect_to new_session_path, notice: "If an account exists with this email, you'll receive reset instructions shortly."
    end
  end

  def update
    if params[:password].blank?
      redirect_to edit_password_path(params[:token]), alert: 'Password required.'
    elsif params[:password_confirmation].blank?
      redirect_to edit_password_path(params[:token]), alert: 'Password confirmation required.'
    elsif @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all

      redirect_to new_session_path, notice: 'Password updated.'
    else
      redirect_to edit_password_path(params[:token]), alert: 'Passwords did not match.'
    end
  end

  private

  def set_user_by_token
    # rubocop:disable Rails/DynamicFindBy
    @user = User.find_by_password_reset_token!(params[:token])
    # rubocop:enable Rails/DynamicFindBy
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: 'Password reset link is invalid or has expired.'
  end
end
