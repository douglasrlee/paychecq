class BanksController < ApplicationController
  def create
    client = Plaid::PlaidApi.new(Plaid::ApiClient.new)

    # Exchange public token for access token
    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(
      public_token: params[:public_token]
    )
    exchange_response = client.item_public_token_exchange(exchange_request)

    # Fetch institution details including logo
    institution_request = Plaid::InstitutionsGetByIdRequest.new(
      institution_id: params[:institution_id],
      country_codes: [ 'US' ],
      options: { include_optional_metadata: true }
    )
    institution_response = client.institutions_get_by_id(institution_request)
    institution = institution_response.institution

    # Create the bank record
    bank = Current.user.banks.create!(
      name: params[:institution_name],
      plaid_item_id: exchange_response.item_id,
      plaid_access_token: exchange_response.access_token,
      plaid_institution_id: params[:institution_id],
      plaid_institution_name: params[:institution_name],
      logo: institution.logo
    )

    # Fetch and save accounts
    accounts_request = Plaid::AccountsGetRequest.new(
      access_token: exchange_response.access_token
    )
    accounts_response = client.accounts_get(accounts_request)

    accounts_response.accounts.each do |account|
      bank.bank_accounts.create!(
        plaid_account_id: account.account_id,
        name: account.name,
        official_name: account.official_name,
        masked_account_number: account.mask,
        account_type: account.type,
        account_subtype: account.subtype,
        available_balance: account.balances.available,
        current_balance: account.balances.current,
        last_synced_at: Time.current
      )
    end

    redirect_to settings_path, notice: 'Bank account linked successfully.'
  rescue Plaid::ApiError => e
    Rails.logger.error("Plaid error: #{e.response_body}")
    redirect_to settings_path, alert: 'Failed to link bank account. Please try again.'
  end

  def destroy
    bank = Current.user.banks.find(params[:id])
    bank.destroy

    redirect_to settings_path, notice: 'Bank account deleted successfully.'
  end
end
