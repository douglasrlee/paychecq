Plaid.configure do |config|
  config.server_index = Plaid::Configuration::Environment[ENV.fetch('PLAID_ENV', 'sandbox')]
  config.api_key['PLAID-CLIENT-ID'] = ENV.fetch('PLAID_CLIENT_ID', nil)
  config.api_key['PLAID-SECRET'] = ENV.fetch('PLAID_SECRET', nil)
end
