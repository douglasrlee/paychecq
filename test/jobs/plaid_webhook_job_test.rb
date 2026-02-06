require 'test_helper'

class PlaidWebhookJobTest < ActiveJob::TestCase
  setup do
    @original_sync = TransactionSyncService.method(:sync)
    @original_remove_item = PlaidService.method(:remove_item)
  end

  teardown do
    TransactionSyncService.define_singleton_method(:sync, @original_sync)
    PlaidService.define_singleton_method(:remove_item, @original_remove_item)
  end

  test 'routes TRANSACTIONS webhook to TransactionSyncService' do
    bank = banks(:chase)
    synced_bank = nil

    TransactionSyncService.define_singleton_method(:sync) { |bank:| synced_bank = bank }

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'TRANSACTIONS',
      'webhook_code' => 'SYNC_UPDATES_AVAILABLE',
      'item_id' => bank.plaid_item_id
    )

    assert_equal bank, synced_bank
  end

  test 'ignores unknown webhook types' do
    synced = false

    TransactionSyncService.define_singleton_method(:sync) { |**| synced = true }

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'UNKNOWN_TYPE',
      'webhook_code' => 'SOMETHING',
      'item_id' => banks(:chase).plaid_item_id
    )

    assert_not synced
  end

  test 'handles missing bank gracefully' do
    synced = false

    TransactionSyncService.define_singleton_method(:sync) { |**| synced = true }

    assert_nothing_raised do
      PlaidWebhookJob.perform_now(
        'webhook_type' => 'TRANSACTIONS',
        'webhook_code' => 'SYNC_UPDATES_AVAILABLE',
        'item_id' => 'nonexistent_item_id'
      )
    end

    assert_not synced
  end

  test 'retries on Plaid API error' do
    error = Plaid::ApiError.new(
      response_body: '{"error_type":"API_ERROR"}',
      code: 500,
      response_headers: {}
    )

    TransactionSyncService.define_singleton_method(:sync) { |**| raise error }

    assert_enqueued_with(job: PlaidWebhookJob) do
      PlaidWebhookJob.perform_now(
        'webhook_type' => 'TRANSACTIONS',
        'webhook_code' => 'SYNC_UPDATES_AVAILABLE',
        'item_id' => banks(:chase).plaid_item_id
      )
    end
  end

  test 'ITEM ERROR marks bank as error with error code' do
    bank = create_bank(email: 'item_error@example.com', plaid_item_id: 'item_error_test')

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'ITEM',
      'webhook_code' => 'ERROR',
      'item_id' => bank.plaid_item_id,
      'error' => { 'error_code' => 'ITEM_LOGIN_REQUIRED', 'error_type' => 'ITEM_ERROR' }
    )

    bank.reload
    assert_equal 'error', bank.status
    assert_equal 'ITEM_LOGIN_REQUIRED', bank.plaid_error_code
  end

  test 'ITEM PENDING_EXPIRATION marks bank as pending_expiration' do
    bank = create_bank(email: 'item_pending@example.com', plaid_item_id: 'item_pending_test')

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'ITEM',
      'webhook_code' => 'PENDING_EXPIRATION',
      'item_id' => bank.plaid_item_id
    )

    bank.reload
    assert_equal 'pending_expiration', bank.status
  end

  test 'ITEM USER_PERMISSION_REVOKED removes item from Plaid and marks bank as disconnected' do
    bank = create_bank(email: 'item_revoked@example.com', plaid_item_id: 'item_revoked_test')

    removed_token = nil
    PlaidService.define_singleton_method(:remove_item) { |token| removed_token = token; true }

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'ITEM',
      'webhook_code' => 'USER_PERMISSION_REVOKED',
      'item_id' => bank.plaid_item_id
    )

    bank.reload
    assert_equal 'disconnected', bank.status
    assert_equal bank.plaid_access_token, removed_token
  end

  test 'ITEM LOGIN_REPAIRED marks bank as healthy and syncs transactions' do
    bank = create_bank(email: 'item_repaired@example.com', plaid_item_id: 'item_repaired_test')
    bank.update!(status: 'error', plaid_error_code: 'ITEM_LOGIN_REQUIRED')

    synced_bank = nil
    TransactionSyncService.define_singleton_method(:sync) { |bank:| synced_bank = bank }

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'ITEM',
      'webhook_code' => 'LOGIN_REPAIRED',
      'item_id' => bank.plaid_item_id
    )

    bank.reload
    assert_equal 'healthy', bank.status
    assert_nil bank.plaid_error_code
    assert_equal bank, synced_bank
  end

  test 'ITEM webhook handles missing bank gracefully' do
    assert_nothing_raised do
      PlaidWebhookJob.perform_now(
        'webhook_type' => 'ITEM',
        'webhook_code' => 'ERROR',
        'item_id' => 'nonexistent_item_id',
        'error' => { 'error_code' => 'ITEM_LOGIN_REQUIRED' }
      )
    end
  end

  private

  def create_bank(email:, plaid_item_id:)
    user = User.create!(first_name: 'Webhook', last_name: 'Test', email_address: email, password: 'password')

    Bank.create!(
      user: user,
      name: 'Test Bank',
      plaid_item_id: plaid_item_id,
      plaid_access_token: 'access_token_test',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )
  end
end
