class TransactionSyncService
  def self.sync(bank:)
    result = PlaidService.sync_transactions(bank.plaid_access_token, cursor: bank.transaction_cursor)

    account_map = bank.bank_accounts.pluck(:plaid_account_id, :id).to_h

    new_transactions = upsert_transactions(result[:added] + result[:modified], account_map)
    remove_transactions(result[:removed])

    bank.update!(transaction_cursor: result[:cursor])
    refresh_bank_accounts(bank, result[:accounts])

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
      transaction.assign_attributes(attributes_from_plaid(plaid_transaction, bank_account_id))
      transaction.save!
      new_transactions << transaction if is_new
    end

    new_transactions
  end

  private_class_method :upsert_transactions

  # Top-level `logo_url` / `merchant_entity_id` are nil for transactions whose primary counterparty
  # is a financial institution (e.g. credit-card payments). Fall back to the first counterparty.
  def self.attributes_from_plaid(plaid_transaction, bank_account_id)
    counterparty = plaid_transaction.counterparties&.first

    {
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
      logo_url: plaid_transaction.logo_url || counterparty&.logo_url,
      merchant_entity_id: plaid_transaction.merchant_entity_id || counterparty&.entity_id
    }
  end

  private_class_method :attributes_from_plaid

  def self.remove_transactions(removed)
    return if removed.empty?

    plaid_ids = removed.map(&:transaction_id)

    Transaction.where(plaid_transaction_id: plaid_ids).destroy_all
  end

  private_class_method :remove_transactions

  # Bump `last_synced_at` on every bank_account, and refresh balances for any
  # account included in the Plaid sync response.
  def self.refresh_bank_accounts(bank, plaid_accounts)
    balances_by_plaid_id = (plaid_accounts || []).index_by(&:account_id)
    synced_at = Time.current

    bank.bank_accounts.find_each do |account|
      attrs = { last_synced_at: synced_at }

      if (plaid_account = balances_by_plaid_id[account.plaid_account_id])
        attrs[:available_balance] = plaid_account.balances.available
        attrs[:current_balance] = plaid_account.balances.current
      end

      account.update!(attrs)
    end
  end

  private_class_method :refresh_bank_accounts
end
