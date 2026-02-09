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
end
