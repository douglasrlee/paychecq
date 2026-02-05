class SettingsController < ApplicationController
  def show
    @bank = Current.user.banks.includes(:bank_accounts).first

    return if @bank

    @plaid_link_token = PlaidService.create_link_token(Current.user)

    flash.now[:alert] = 'Unable to initialize bank linking. Please try again later.' unless @plaid_link_token
  end
end
