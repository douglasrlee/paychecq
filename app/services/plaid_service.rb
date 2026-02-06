class PlaidService
  def self.create_link_token(user)
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: user.id },
      client_name: 'PayChecQ',
      products: [ 'transactions' ],
      country_codes: [ 'US' ],
      language: 'en',
      webhook: ENV.fetch('PLAID_WEBHOOK_URL', nil),
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

  def self.create_update_link_token(bank)
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: bank.user_id },
      client_name: 'PayChecQ',
      country_codes: [ 'US' ],
      language: 'en',
      webhook: ENV.fetch('PLAID_WEBHOOK_URL', nil),
      access_token: bank.plaid_access_token
    )

    response = client.link_token_create(request)
    response.link_token
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid update link token error: #{error.response_body}")
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

  def self.sync_transactions(access_token, cursor: nil)
    added = []
    modified = []
    removed = []

    loop do
      request = Plaid::TransactionsSyncRequest.new(
        access_token: access_token,
        cursor: cursor
      )
      response = client.transactions_sync(request)

      added.concat(response.added)
      modified.concat(response.modified)
      removed.concat(response.removed)
      cursor = response.next_cursor

      break unless response.has_more
    end

    { added: added, modified: modified, removed: removed, cursor: cursor }
  end

  def self.verify_webhook(body, plaid_verification_header)
    # Decode ::JWT header to get the key ID without verifying signature yet
    header = ::JWT.decode(plaid_verification_header, nil, false).last
    key_id = header['kid']

    # Fetch the verification key from Plaid
    request = Plaid::WebhookVerificationKeyGetRequest.new(key_id: key_id)
    response = client.webhook_verification_key_get(request)
    jwk = response.key.to_hash

    # Verify the ::JWT signature using the JWK
    decoded = ::JWT.decode(
      plaid_verification_header,
      nil,
      true,
      algorithms: [ 'ES256' ],
      jwks: { keys: [ jwk ] }
    ).first

    # Verify the token is not older than 5 minutes
    issued_at = Time.zone.at(decoded['iat'])

    raise ::JWT::ExpiredSignature, 'Webhook too old' if Time.current - issued_at > 5.minutes

    # Verify the request body hash matches
    expected_hash = decoded['request_body_sha256']
    actual_hash = Digest::SHA256.hexdigest(body)

    raise ::JWT::VerificationError, 'Body hash mismatch' unless ActiveSupport::SecurityUtils.secure_compare(expected_hash, actual_hash)
  end

  def self.client
    Plaid::PlaidApi.new(Plaid::ApiClient.new)
  end

  private_class_method :client
end
