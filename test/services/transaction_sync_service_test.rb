require 'test_helper'

class TransactionSyncServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  PlaidTransaction = Struct.new(
    :transaction_id, :account_id, :name, :amount, :date, :authorized_date,
    :merchant_name, :pending, :payment_channel, :personal_finance_category,
    :logo_url, :merchant_entity_id, :counterparties
  )

  PlaidCategory = Struct.new(:primary, :detailed)
  PlaidCounterparty = Struct.new(:name, :type, :logo_url, :entity_id)
  PlaidRemoved = Struct.new(:transaction_id)

  setup do
    @user = User.create!(
      first_name: 'Sync',
      last_name: 'Test',
      email_address: "sync_#{SecureRandom.hex(4)}@example.com",
      password: 'password'
    )

    @bank = Bank.create!(
      user: @user,
      name: 'Test Bank',
      plaid_item_id: "item_sync_#{SecureRandom.hex(4)}",
      plaid_access_token: 'access_token_sync',
      plaid_institution_id: 'ins_sync',
      plaid_institution_name: 'Test Bank'
    )

    @bank_account = BankAccount.create!(
      bank: @bank,
      name: 'Test Checking',
      masked_account_number: '9999',
      account_type: 'depository',
      account_subtype: 'checking',
      plaid_account_id: "account_sync_#{SecureRandom.hex(4)}",
      available_balance: 1000.00,
      current_balance: 1000.00,
      last_synced_at: Time.current
    )

    @original_sync = PlaidService.method(:sync_transactions)
  end

  teardown do
    PlaidService.define_singleton_method(:sync_transactions, @original_sync)
  end

  test 'sync creates new transactions from added results' do
    stub_sync_response(added: [ build_plaid_transaction('txn_1', 'Starbucks', 5.50) ])

    assert_difference 'Transaction.count', 1 do
      TransactionSyncService.sync(bank: @bank)
    end

    txn = Transaction.find_by(plaid_transaction_id: 'txn_1')

    assert_equal 'Starbucks', txn.name
    assert_equal 5.50, txn.amount.to_f
    assert_equal @bank_account.id, txn.bank_account_id
  end

  test 'sync falls back to first counterparty logo_url and entity_id when top-level fields are nil' do
    counterparty = PlaidCounterparty.new(
      name: 'Apple Card',
      type: 'financial_institution',
      logo_url: 'https://plaid-counterparty-logos.plaid.com/apple_card_336.png',
      entity_id: 'entity_apple_card'
    )

    txn_input = build_plaid_transaction(
      'txn_fi_1',
      'WITHDRAWAL ACH APPLECARD GSBANK',
      122.50,
      logo_url: nil,
      merchant_entity_id: nil,
      counterparties: [ counterparty ]
    )

    stub_sync_response(added: [ txn_input ])

    TransactionSyncService.sync(bank: @bank)

    txn = Transaction.find_by(plaid_transaction_id: 'txn_fi_1')

    assert_equal 'https://plaid-counterparty-logos.plaid.com/apple_card_336.png', txn.logo_url
    assert_equal 'entity_apple_card', txn.merchant_entity_id
  end

  test 'sync prefers top-level logo_url and entity_id over counterparty values' do
    counterparty = PlaidCounterparty.new(
      name: 'Other',
      type: 'merchant',
      logo_url: 'https://example.com/counterparty.png',
      entity_id: 'counterparty_entity'
    )

    txn_input = build_plaid_transaction(
      'txn_toplevel_1',
      'Starbucks',
      5.50,
      logo_url: 'https://example.com/top.png',
      merchant_entity_id: 'top_entity',
      counterparties: [ counterparty ]
    )

    stub_sync_response(added: [ txn_input ])

    TransactionSyncService.sync(bank: @bank)

    txn = Transaction.find_by(plaid_transaction_id: 'txn_toplevel_1')

    assert_equal 'https://example.com/top.png', txn.logo_url
    assert_equal 'top_entity', txn.merchant_entity_id
  end

  test 'sync updates existing transactions from modified results' do
    Transaction.create!(
      name: 'Starbucks',
      amount: 5.50,
      plaid_transaction_id: 'txn_1',
      bank_account: @bank_account
    )

    stub_sync_response(modified: [ build_plaid_transaction('txn_1', 'Starbucks Reserve', 7.00) ])

    assert_no_difference 'Transaction.count' do
      TransactionSyncService.sync(bank: @bank)
    end

    txn = Transaction.find_by(plaid_transaction_id: 'txn_1')

    assert_equal 'Starbucks Reserve', txn.name
    assert_equal 7.00, txn.amount.to_f
  end

  test 'sync removes transactions from removed results' do
    Transaction.create!(
      name: 'Old Transaction',
      amount: 10.00,
      plaid_transaction_id: 'txn_remove_1',
      bank_account: @bank_account
    )

    removed = PlaidRemoved.new(transaction_id: 'txn_remove_1')
    stub_sync_response(removed: [ removed ])

    assert_difference 'Transaction.count', -1 do
      TransactionSyncService.sync(bank: @bank)
    end

    assert_nil Transaction.find_by(plaid_transaction_id: 'txn_remove_1')
  end

  test 'sync updates bank transaction_cursor' do
    stub_sync_response(cursor: 'new_cursor_abc')

    TransactionSyncService.sync(bank: @bank)

    assert_equal 'new_cursor_abc', @bank.reload.transaction_cursor
  end

  test 'sync updates bank_accounts last_synced_at' do
    old_synced_at = @bank_account.last_synced_at

    stub_sync_response

    travel 1.minute do
      TransactionSyncService.sync(bank: @bank)
    end

    assert_operator @bank_account.reload.last_synced_at, :>, old_synced_at
  end

  test 'sync skips transactions for unknown account IDs' do
    txn = build_plaid_transaction('txn_unknown', 'Mystery', 99.99, account_id: 'unknown_account_id')

    stub_sync_response(added: [ txn ])

    assert_no_difference 'Transaction.count' do
      TransactionSyncService.sync(bank: @bank)
    end
  end

  test 'sync raises Plaid API errors' do
    error = Plaid::ApiError.new(
      response_body: '{"error_type":"API_ERROR"}',
      code: 500,
      response_headers: {}
    )

    PlaidService.define_singleton_method(:sync_transactions) { |*, **| raise error }

    assert_raises(Plaid::ApiError) do
      TransactionSyncService.sync(bank: @bank)
    end
  end

  test 'sync enqueues push notification job for new transactions' do
    stub_sync_response(added: [ build_plaid_transaction('txn_push_1', 'Starbucks', 5.50) ])

    assert_enqueued_with(job: SendPushNotificationJob) do
      TransactionSyncService.sync(bank: @bank)
    end
  end

  test 'sync does not enqueue push notification for modifications only' do
    Transaction.create!(
      name: 'Starbucks',
      amount: 5.50,
      plaid_transaction_id: 'txn_mod_1',
      bank_account: @bank_account
    )

    stub_sync_response(modified: [ build_plaid_transaction('txn_mod_1', 'Starbucks Reserve', 7.00) ])

    assert_no_enqueued_jobs(only: SendPushNotificationJob) do
      TransactionSyncService.sync(bank: @bank)
    end
  end

  test 'sync passes existing cursor to PlaidService' do
    @bank.update!(transaction_cursor: 'existing_cursor')

    called_with_cursor = nil
    PlaidService.define_singleton_method(:sync_transactions) do |_access_token, cursor:|
      called_with_cursor = cursor
      { added: [], modified: [], removed: [], cursor: 'new_cursor' }
    end

    TransactionSyncService.sync(bank: @bank)

    assert_equal 'existing_cursor', called_with_cursor
  end

  private

  def build_plaid_transaction(id, name, amount, account_id: nil, logo_url: 'https://example.com/logo.png', merchant_entity_id: 'merchant_123', counterparties: nil) # rubocop:disable Metrics/ParameterLists
    PlaidTransaction.new(
      transaction_id: id,
      account_id: account_id || @bank_account.plaid_account_id,
      name: name,
      amount: amount,
      date: Date.current,
      authorized_date: Date.current,
      merchant_name: name,
      pending: false,
      payment_channel: 'in store',
      personal_finance_category: PlaidCategory.new(primary: 'FOOD_AND_DRINK', detailed: 'FOOD_AND_DRINK_COFFEE'),
      logo_url: logo_url,
      merchant_entity_id: merchant_entity_id,
      counterparties: counterparties
    )
  end

  def stub_sync_response(added: [], modified: [], removed: [], cursor: 'cursor_abc')
    result = { added: added, modified: modified, removed: removed, cursor: cursor }
    PlaidService.define_singleton_method(:sync_transactions) { |*, **| result }
  end
end
