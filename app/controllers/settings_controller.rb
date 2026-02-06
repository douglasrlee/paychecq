class SettingsController < ApplicationController
  def show
    @bank = Current.user.banks.includes(:bank_accounts).first

    if @bank
      @plaid_update_link_token = PlaidService.create_update_link_token(@bank) if @bank.needs_attention? && !@bank.disconnected?
    else
      @plaid_link_token = PlaidService.create_link_token(Current.user)

      flash.now[:alert] = 'Unable to initialize bank linking. Please try again later.' unless @plaid_link_token
    end
  end
end
