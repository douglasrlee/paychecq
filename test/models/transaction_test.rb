require 'test_helper'

class TransactionTest < ActiveSupport::TestCase
  test 'is valid with name and amount' do
    transaction = Transaction.new(name: 'Grocery Store', amount: 50.00)

    assert transaction.valid?
  end

  test 'is invalid without name' do
    transaction = Transaction.new(amount: 50.00)

    assert_not transaction.valid?
    assert_includes transaction.errors[:name], "can't be blank"
  end

  test 'is invalid without amount' do
    transaction = Transaction.new(name: 'Grocery Store')

    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], "can't be blank"
  end

  test 'is invalid with non-numeric amount' do
    transaction = Transaction.new(name: 'Grocery Store', amount: 'not a number')

    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], 'is not a number'
  end

  test 'plaid_transaction_id must be unique' do
    Transaction.create!(name: 'First', amount: 10.00, plaid_transaction_id: 'plaid_unique_123')
    duplicate = Transaction.new(name: 'Second', amount: 20.00, plaid_transaction_id: 'plaid_unique_123')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:plaid_transaction_id], 'has already been taken'
  end

  test 'plaid_transaction_id allows multiple nils' do
    Transaction.create!(name: 'Manual 1', amount: 10.00, plaid_transaction_id: nil)
    manual2 = Transaction.new(name: 'Manual 2', amount: 20.00, plaid_transaction_id: nil)

    assert manual2.valid?
  end

  test 'bank_account is optional' do
    transaction = Transaction.new(name: 'Manual Entry', amount: 25.00)

    assert transaction.valid?
    assert_nil transaction.bank_account
  end

  test 'belongs to bank_account' do
    bank_account = bank_accounts(:chase_checking)
    transaction = Transaction.create!(name: 'Linked', amount: 15.00, bank_account: bank_account)

    assert_equal bank_account, transaction.bank_account
  end

  test 'safe_logo_url returns https url' do
    transaction = Transaction.new(name: 'Test', amount: 10, logo_url: 'https://example.com/logo.png')

    assert_equal 'https://example.com/logo.png', transaction.safe_logo_url
  end

  test 'safe_logo_url returns http url' do
    transaction = Transaction.new(name: 'Test', amount: 10, logo_url: 'http://example.com/logo.png')

    assert_equal 'http://example.com/logo.png', transaction.safe_logo_url
  end

  test 'safe_logo_url rejects non-http schemes' do
    transaction = Transaction.new(name: 'Test', amount: 10, logo_url: 'javascript:alert(1)')

    assert_nil transaction.safe_logo_url
  end

  test 'safe_logo_url returns nil for blank url' do
    transaction = Transaction.new(name: 'Test', amount: 10, logo_url: '')

    assert_nil transaction.safe_logo_url
  end

  test 'safe_logo_url returns nil for invalid url' do
    transaction = Transaction.new(name: 'Test', amount: 10, logo_url: '://bad')

    assert_nil transaction.safe_logo_url
  end

  test 'display_name returns raw name when no overrides match' do
    transaction = Transaction.new(name: 'AMAZON', amount: 10)
    overrides = [ build_override('exact', 'STARBUCKS', 'Coffee') ]

    assert_equal 'AMAZON', transaction.display_name(overrides)
  end

  test 'display_name returns override replacement on exact match (case-insensitive)' do
    transaction = Transaction.new(name: 'starbucks', amount: 10)
    overrides = [ build_override('exact', 'STARBUCKS', 'Coffee') ]

    assert_equal 'Coffee', transaction.display_name(overrides)
  end

  test 'display_name returns override replacement on contains match (case-insensitive)' do
    transaction = Transaction.new(name: 'Uber 072515 SF**POOL**', amount: 10)
    overrides = [ build_override('contains', 'uber', 'Rideshare') ]

    assert_equal 'Rideshare', transaction.display_name(overrides)
  end

  test 'applied_override prefers exact over contains when both match' do
    transaction = Transaction.new(name: 'STARBUCKS Coffee', amount: 10)
    contains_override = build_override('contains', 'starbucks', 'CoffeeShop')
    exact_override = build_override('exact', 'STARBUCKS Coffee', 'Morning Coffee')
    overrides = [ contains_override, exact_override ]

    assert_equal exact_override, transaction.applied_override(overrides)
    assert_equal 'Morning Coffee', transaction.display_name(overrides)
  end

  test 'display_label falls back to merchant_name when no override matches' do
    transaction = Transaction.new(name: 'WHOLEFDS MKT #10', merchant_name: 'Whole Foods', amount: 10)

    assert_equal 'Whole Foods', transaction.display_label([])
  end

  test 'display_label falls back to raw name when no override or merchant_name' do
    transaction = Transaction.new(name: 'CASH WITHDRAWAL', amount: 10)

    assert_equal 'CASH WITHDRAWAL', transaction.display_label([])
  end

  test 'display_label prefers override over merchant_name' do
    transaction = Transaction.new(name: 'UBER', merchant_name: 'Uber', amount: 10)
    overrides = [ build_override('exact', 'UBER', 'Rideshare') ]

    assert_equal 'Rideshare', transaction.display_label(overrides)
  end

  private

  def build_override(match_type, match_text, replacement_name)
    TransactionNameOverride.new(match_type: match_type, match_text: match_text, replacement_name: replacement_name)
  end
end
