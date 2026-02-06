class PlaidWebhookJob < ApplicationJob
  retry_on Plaid::ApiError, wait: ->(attempt) { (2**attempt).minutes }, attempts: 5

  def perform(payload)
    return unless payload['webhook_type'] == 'TRANSACTIONS'

    bank = Bank.find_by(plaid_item_id: payload['item_id'])

    return unless bank

    TransactionSyncService.sync(bank: bank)
  end
end
