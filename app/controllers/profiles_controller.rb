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
      redirect_to profile_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def edit_password
    @user = Current.user
  end

  def update_password
    @user = Current.user

    if !@user.authenticate(params[:current_password])
      @user.errors.add(:current_password, 'is incorrect')

      render :edit_password, status: :unprocessable_content
    elsif @user.update(password_params)
      redirect_to profile_path
    else
      render :edit_password, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.expect(user: [ :first_name, :last_name, :email_address ])
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
