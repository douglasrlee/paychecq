class TransactionSyncService
  def self.sync(bank:)
    result = PlaidService.sync_transactions(bank.plaid_access_token, cursor: bank.transaction_cursor)

    account_map = bank.bank_accounts.pluck(:plaid_account_id, :id).to_h

    new_transactions = upsert_transactions(result[:added] + result[:modified], account_map)
    remove_transactions(result[:removed])

    bank.update!(transaction_cursor: result[:cursor])
    bank.bank_accounts.find_each { |account| account.update!(last_synced_at: Time.current) }

    SendPushNotificationJob.perform_later(bank.user_id, new_transactions.map(&:id)) if new_transactions.any?
  rescue Plaid::ApiError => error
    Rails.logger.error("Transaction sync error: #{error.response_body}")
    Appsignal.send_error(error)

    raise
  end

  def self.upsert_transactions(plaid_transactions, account_map)
    return [] if plaid_transactions.empty?

    new_transactions = []

    plaid_transactions.each do |plaid_transaction|
      bank_account_id = account_map[plaid_transaction.account_id]
      next unless bank_account_id

      transaction = Transaction.find_or_initialize_by(plaid_transaction_id: plaid_transaction.transaction_id)
      is_new = transaction.new_record?
      transaction.assign_attributes(
        bank_account_id: bank_account_id,
        name: plaid_transaction.name,
        amount: plaid_transaction.amount,
        date: plaid_transaction.date,
        authorized_date: plaid_transaction.authorized_date,
        merchant_name: plaid_transaction.merchant_name,
        pending: plaid_transaction.pending,
        payment_channel: plaid_transaction.payment_channel,
        personal_finance_category: plaid_transaction.personal_finance_category&.primary,
        personal_finance_category_detailed: plaid_transaction.personal_finance_category&.detailed,
        logo_url: plaid_transaction.logo_url,
        merchant_entity_id: plaid_transaction.merchant_entity_id
      )
      transaction.save!
      new_transactions << transaction if is_new
    end

    new_transactions
  end

  private_class_method :upsert_transactions

  def self.remove_transactions(removed)
    return if removed.empty?

    plaid_ids = removed.map(&:transaction_id)

    Transaction.where(plaid_transaction_id: plaid_ids).destroy_all
  end

  private_class_method :remove_transactions
end
