class SettingsController < ApplicationController
  def show
    @bank = Current.user.banks.includes(:bank_accounts).first
    @plaid_link_token = PlaidService.create_link_token(Current.user) unless @bank
  end
end
