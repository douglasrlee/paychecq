require 'test_helper'

class BankAccountTest < ActiveSupport::TestCase
  test 'is valid with all required attributes' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      name: 'Test Account',
      masked_account_number: '9999',
      account_type: 'depository',
      plaid_account_id: 'account_test_123',
      last_synced_at: Time.current
    )

    assert bank_account.valid?
  end

  test 'is invalid without a bank' do
    bank_account = BankAccount.new(
      name: 'Test Account',
      masked_account_number: '9999',
      account_type: 'depository',
      plaid_account_id: 'account_test_123',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:bank], 'must exist'
  end

  test 'is invalid without a name' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      masked_account_number: '9999',
      account_type: 'depository',
      plaid_account_id: 'account_test_123',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:name], "can't be blank"
  end

  test 'is invalid without masked_account_number' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      name: 'Test Account',
      account_type: 'depository',
      plaid_account_id: 'account_test_123',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:masked_account_number], "can't be blank"
  end

  test 'is invalid without account_type' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      name: 'Test Account',
      masked_account_number: '9999',
      plaid_account_id: 'account_test_123',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:account_type], "can't be blank"
  end

  test 'is invalid without plaid_account_id' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      name: 'Test Account',
      masked_account_number: '9999',
      account_type: 'depository',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:plaid_account_id], "can't be blank"
  end

  test 'is invalid without last_synced_at' do
    bank_account = BankAccount.new(
      bank: banks(:chase),
      name: 'Test Account',
      masked_account_number: '9999',
      account_type: 'depository',
      plaid_account_id: 'account_test_123'
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:last_synced_at], "can't be blank"
  end

  test 'is invalid with duplicate plaid_account_id' do
    BankAccount.create!(
      bank: banks(:chase),
      name: 'Existing Account',
      masked_account_number: '1111',
      account_type: 'depository',
      plaid_account_id: 'duplicate_account_id',
      last_synced_at: Time.current
    )

    bank_account = BankAccount.new(
      bank: banks(:wells_fargo),
      name: 'New Account',
      masked_account_number: '2222',
      account_type: 'depository',
      plaid_account_id: 'duplicate_account_id',
      last_synced_at: Time.current
    )

    assert_not bank_account.valid?
    assert_includes bank_account.errors[:plaid_account_id], 'has already been taken'
  end

  test 'delegates user to bank' do
    bank_account = bank_accounts(:chase_checking)

    assert_equal banks(:chase).user, bank_account.user
  end
end
