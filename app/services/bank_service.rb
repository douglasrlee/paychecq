class BankService
  Result = Data.define(:success, :error)

  def self.link(user:, public_token:, institution_id:, institution_name:)
    exchange_response = PlaidService.exchange_public_token(public_token)
    logo = PlaidService.get_institution_logo(institution_id)
    accounts = PlaidService.get_accounts(exchange_response.access_token)

    if accounts.empty?
      PlaidService.remove_item(exchange_response.access_token)

      return Result.new(success: false, error: 'No accounts found at this institution. Please try a different bank.')
    end

    ActiveRecord::Base.transaction do
      bank = user.banks.create!(
        name: institution_name,
        plaid_item_id: exchange_response.item_id,
        plaid_access_token: exchange_response.access_token,
        plaid_institution_id: institution_id,
        plaid_institution_name: institution_name,
        logo: logo
      )

      accounts.each do |account|
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

    Result.new(success: true, error: nil)
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid error: #{error.response_body}")
    Appsignal.send_error(error)

    PlaidService.remove_item(exchange_response.access_token) if exchange_response

    Result.new(success: false, error: 'Failed to link bank account. Please try again.')
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.error("Bank creation error: #{error.message}")
    Appsignal.send_error(error)

    PlaidService.remove_item(exchange_response.access_token)

    Result.new(success: false, error: 'Failed to link bank account. Please try again.')
  end
end
