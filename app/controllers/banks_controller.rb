class BanksController < ApplicationController
  def create
    client = Plaid::PlaidApi.new(Plaid::ApiClient.new)

    # Exchange public token for access token
    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(
      public_token: params[:public_token]
    )
    exchange_response = client.item_public_token_exchange(exchange_request)

    # Fetch institution logo (optional - don't fail if this doesn't work)
    logo = begin
      institution_request = Plaid::InstitutionsGetByIdRequest.new(
        institution_id: params[:institution_id],
        country_codes: [ 'US' ],
        options: { include_optional_metadata: true }
      )
      institution_response = client.institutions_get_by_id(institution_request)
      institution_response.institution.logo
    rescue Plaid::ApiError => error
      Rails.logger.warn("Failed to fetch institution logo: #{error.response_body}")
      Appsignal.send_error(error)
      nil
    end

    # Fetch accounts
    accounts_request = Plaid::AccountsGetRequest.new(
      access_token: exchange_response.access_token
    )
    accounts_response = client.accounts_get(accounts_request)

    # Ensure at least one account was returned
    if accounts_response.accounts.empty?
      PlaidService.remove_item(exchange_response.access_token)

      return redirect_to settings_path, alert: 'No accounts found at this institution. Please try a different bank.'
    end

    # Create bank and accounts in a transaction
    ActiveRecord::Base.transaction do
      bank = Current.user.banks.create!(
        name: params[:institution_name],
        plaid_item_id: exchange_response.item_id,
        plaid_access_token: exchange_response.access_token,
        plaid_institution_id: params[:institution_id],
        plaid_institution_name: params[:institution_name],
        logo: logo
      )

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
    end

    redirect_to settings_path, notice: 'Bank account linked successfully.'
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid error: #{error.response_body}")
    Appsignal.send_error(error)

    # Clean up the Plaid item if we have an access token (token exchange succeeded but a later call failed)
    PlaidService.remove_item(exchange_response.access_token) if exchange_response

    redirect_to settings_path, alert: 'Failed to link bank account. Please try again.'
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.error("Bank creation error: #{error.message}")
    Appsignal.send_error(error)

    # Clean up the Plaid item since we couldn't save the bank record
    PlaidService.remove_item(exchange_response.access_token)

    redirect_to settings_path, alert: 'Failed to link bank account. Please try again.'
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
