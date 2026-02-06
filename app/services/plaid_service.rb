class PlaidService
  def self.create_link_token(user)
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: user.id },
      client_name: 'PayChecQ',
      products: [ 'transactions' ],
      country_codes: [ 'US' ],
      language: 'en',
      account_filters: {
        depository: { account_subtypes: [ 'checking' ] }
      }
    )

    response = client.link_token_create(request)
    response.link_token
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid link token error: #{error.response_body}")
    Appsignal.send_error(error)

    nil
  end

  def self.exchange_public_token(public_token)
    request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)

    client.item_public_token_exchange(request)
  end

  def self.get_institution_logo(institution_id)
    request = Plaid::InstitutionsGetByIdRequest.new(
      institution_id: institution_id,
      country_codes: [ 'US' ],
      options: { include_optional_metadata: true }
    )

    response = client.institutions_get_by_id(request)
    response.institution.logo
  rescue Plaid::ApiError => error
    Rails.logger.warn("Failed to fetch institution logo: #{error.response_body}")
    Appsignal.send_error(error)

    nil
  end

  def self.get_accounts(access_token)
    request = Plaid::AccountsGetRequest.new(access_token: access_token)

    response = client.accounts_get(request)
    response.accounts
  end

  def self.remove_item(access_token)
    request = Plaid::ItemRemoveRequest.new(access_token: access_token)
    client.item_remove(request)

    true
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid remove item error: #{error.response_body}")
    Appsignal.send_error(error)

    false
  end

  def self.client
    Plaid::PlaidApi.new(Plaid::ApiClient.new)
  end

  private_class_method :client
end
