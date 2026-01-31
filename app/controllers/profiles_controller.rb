class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to profile_path, notice: 'Profile updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def edit_security
    @user = Current.user
  end

  def update_security
    @user = Current.user

    if @user.authenticate(login_params[:current_password])
      email_changed = @user.email_address != login_params[:email_address]
      password_changed = login_params[:password].present?

      if @user.update(login_update_params)
        @user.sessions.where.not(id: Current.session.id).destroy_all if password_changed

        redirect_to profile_path, notice: security_update_notice(email_changed, password_changed)
      else
        render :edit_security, status: :unprocessable_content
      end
    else
      @user.errors.add(:current_password, 'is incorrect')

      render :edit_security, status: :unprocessable_content
    end
  end

  private

  def security_update_notice(email_changed, password_changed)
    if email_changed && password_changed
      'Email and password updated. Other devices have been signed out.'
    elsif password_changed
      'Password updated. Other devices have been signed out.'
    else
      'Email updated.'
    end
  end

  def user_params
    params.expect(user: [ :first_name, :last_name ])
  end

  def login_params
    params.expect(login: [ :current_password, :email_address, :password, :password_confirmation ])
  end

  def login_update_params
    permitted = login_params.slice(:email_address)
    permitted[:password] = login_params[:password] if login_params[:password].present?
    permitted[:password_confirmation] = login_params[:password_confirmation] if login_params[:password].present?
    permitted
  end
end
