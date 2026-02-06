class BanksController < ApplicationController
  def create
    result = BankService.link(
      user: Current.user,
      public_token: params[:public_token],
      institution_id: params[:institution_id],
      institution_name: params[:institution_name]
    )

    if result.success
      redirect_to settings_path, notice: 'Bank account linked successfully.'
    else
      redirect_to settings_path, alert: result.error
    end
  end

  def destroy
    bank = Current.user.banks.find(params[:id])

    if bank.destroy
      redirect_to settings_path, notice: 'Bank account deleted successfully.'
    else
      redirect_to settings_path, alert: bank.errors.full_messages.first || 'Failed to delete bank account.'
    end
  end
end
