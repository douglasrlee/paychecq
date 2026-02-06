require 'test_helper'

class PlaidWebhookJobTest < ActiveJob::TestCase
  setup do
    @original_sync = TransactionSyncService.method(:sync)
  end

  teardown do
    TransactionSyncService.define_singleton_method(:sync, @original_sync)
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

  test 'ignores non-TRANSACTIONS webhooks' do
    synced = false

    TransactionSyncService.define_singleton_method(:sync) { |**| synced = true }

    PlaidWebhookJob.perform_now(
      'webhook_type' => 'ITEM',
      'webhook_code' => 'WEBHOOK_UPDATE_ACKNOWLEDGED',
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
end
