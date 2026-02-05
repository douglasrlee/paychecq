require 'test_helper'

class BankTest < ActiveSupport::TestCase
  test 'is valid with all required attributes' do
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert bank.valid?
  end

  test 'is invalid without a user' do
    bank = Bank.new(
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:user], 'must exist'
  end

  test 'is invalid without a name' do
    bank = Bank.new(
      user: users(:johndoe),
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:name], "can't be blank"
  end

  test 'is invalid without plaid_item_id' do
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_item_id], "can't be blank"
  end

  test 'is invalid without plaid_access_token' do
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_access_token], "can't be blank"
  end

  test 'is invalid without plaid_institution_id' do
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_institution_id], "can't be blank"
  end

  test 'is invalid without plaid_institution_name' do
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_institution_name], "can't be blank"
  end

  test 'is invalid with duplicate plaid_item_id' do
    Bank.create!(
      user: users(:johndoe),
      name: 'Existing Bank',
      plaid_item_id: 'duplicate_item_id',
      plaid_access_token: 'access_token_1',
      plaid_institution_id: 'ins_1',
      plaid_institution_name: 'Existing Bank'
    )

    bank = Bank.new(
      user: users(:janedoe),
      name: 'New Bank',
      plaid_item_id: 'duplicate_item_id',
      plaid_access_token: 'access_token_2',
      plaid_institution_id: 'ins_2',
      plaid_institution_name: 'New Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_item_id], 'has already been taken'
  end

  test 'encrypts plaid_access_token' do
    bank = Bank.create!(
      user: users(:johndoe),
      name: 'Encryption Test Bank',
      plaid_item_id: 'item_encryption_test',
      plaid_access_token: 'secret_token_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    # Verify the token is readable
    assert_equal 'secret_token_123', bank.plaid_access_token

    # Verify it's encrypted in the database
    raw_value = Bank.connection.select_value(
      "SELECT plaid_access_token FROM banks WHERE id = '#{bank.id}'"
    )
    assert_not_equal 'secret_token_123', raw_value
    assert raw_value.start_with?('{'), 'Expected encrypted JSON format'
  end

  test 'destroys associated bank_accounts when destroyed' do
    bank = Bank.create!(
      user: users(:johndoe),
      name: 'Test Bank',
      plaid_item_id: 'item_destroy_accounts_test',
      plaid_access_token: 'access_token_destroy_accounts_test',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )
    account = bank.bank_accounts.create!(
      plaid_account_id: 'account_destroy_test',
      name: 'Test Account',
      masked_account_number: '1234',
      account_type: 'depository',
      last_synced_at: Time.current
    )

    bank.destroy

    assert_nil BankAccount.find_by(id: account.id)
  end
end
