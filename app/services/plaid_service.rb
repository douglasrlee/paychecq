class PlaidService
  def self.create_link_token(user)
    client = Plaid::PlaidApi.new(Plaid::ApiClient.new)

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

  def self.remove_item(access_token)
    client = Plaid::PlaidApi.new(Plaid::ApiClient.new)

    request = Plaid::ItemRemoveRequest.new(access_token: access_token)
    client.item_remove(request)

    true
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid remove item error: #{error.response_body}")
    Appsignal.send_error(error)

    false
  end
end
