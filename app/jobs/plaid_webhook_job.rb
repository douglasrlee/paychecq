class PlaidWebhookJob < ApplicationJob
  limits_concurrency to: 1, key: ->(payload) { payload['item_id'] }
  retry_on Plaid::ApiError, wait: ->(attempt) { (2**attempt).minutes }, attempts: 5

  def perform(payload)
    bank = Bank.find_by(plaid_item_id: payload['item_id'])

    return unless bank

    case payload['webhook_type']
    when 'TRANSACTIONS'
      TransactionSyncService.sync(bank: bank)
    when 'ITEM'
      handle_item(bank, payload)
    end
  end

  private

  def handle_item(bank, payload)
    case payload['webhook_code']
    when 'ERROR'
      bank.mark_error!(error_code: payload.dig('error', 'error_code'))
    when 'PENDING_EXPIRATION'
      bank.mark_pending_expiration!
    when 'USER_PERMISSION_REVOKED'
      PlaidService.remove_item(bank.plaid_access_token)

      bank.mark_disconnected!
    when 'LOGIN_REPAIRED'
      bank.mark_healthy!

      TransactionSyncService.sync(bank: bank)
    end
  end
end
