require 'test_helper'

class BankTest < ActiveSupport::TestCase
  test 'is valid with all required attributes' do
    user = User.create!(
      first_name: 'New',
      last_name: 'User',
      email_address: 'newuser@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
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
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'testuser_name@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:name], "can't be blank"
  end

  test 'is invalid without plaid_item_id' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'testuser_item@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_item_id], "can't be blank"
  end

  test 'is invalid without plaid_access_token' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'testuser_token@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_access_token], "can't be blank"
  end

  test 'is invalid without plaid_institution_id' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'testuser_inst@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_name: 'Test Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_institution_id], "can't be blank"
  end

  test 'is invalid without plaid_institution_name' do
    user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'testuser_instname@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_test_123',
      plaid_access_token: 'access_token_test_123',
      plaid_institution_id: 'ins_999'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_institution_name], "can't be blank"
  end

  test 'is invalid with duplicate plaid_item_id' do
    # Use existing fixture bank's plaid_item_id
    bank = Bank.new(
      user: User.create!(
        first_name: 'Test',
        last_name: 'User',
        email_address: 'testuser_dup@example.com',
        password: 'password'
      ),
      name: 'New Bank',
      plaid_item_id: banks(:chase).plaid_item_id,
      plaid_access_token: 'access_token_2',
      plaid_institution_id: 'ins_2',
      plaid_institution_name: 'New Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:plaid_item_id], 'has already been taken'
  end

  test 'is invalid when user already has a bank' do
    # johndoe already has chase bank from fixtures
    bank = Bank.new(
      user: users(:johndoe),
      name: 'Second Bank',
      plaid_item_id: 'item_second_bank',
      plaid_access_token: 'access_token_second',
      plaid_institution_id: 'ins_2',
      plaid_institution_name: 'Second Bank'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:user_id], 'already has a linked bank account'
  end

  test 'encrypts plaid_access_token' do
    user = User.create!(
      first_name: 'Encrypt',
      last_name: 'User',
      email_address: 'encryptuser@example.com',
      password: 'password'
    )

    bank = Bank.create!(
      user: user,
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
      Bank.sanitize_sql_array([ 'SELECT plaid_access_token FROM banks WHERE id = ?', bank.id ])
    )
    assert_not_equal 'secret_token_123', raw_value
    assert raw_value.start_with?('{'), 'Expected encrypted JSON format'
  end

  test 'destroys associated bank_accounts when destroyed' do
    # Mock Plaid item remove (called on destroy callback)
    stub_request(:post, 'https://sandbox.plaid.com/item/remove')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { request_id: 'req-remove' }.to_json
      )

    user = User.create!(
      first_name: 'Destroy',
      last_name: 'User',
      email_address: 'destroyuser@example.com',
      password: 'password'
    )

    bank = Bank.create!(
      user: user,
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

  test 'is invalid with non-base64 logo' do
    user = User.create!(
      first_name: 'Logo',
      last_name: 'User',
      email_address: 'logouser_invalid@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_logo_test',
      plaid_access_token: 'access_token_logo_test',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank',
      logo: 'not-valid-base64!!!'
    )

    assert_not bank.valid?
    assert_includes bank.errors[:logo], 'must be valid base64-encoded data'
  end

  test 'is invalid with non-image base64 logo' do
    user = User.create!(
      first_name: 'Logo',
      last_name: 'User',
      email_address: 'logouser_nonimage@example.com',
      password: 'password'
    )

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_logo_test2',
      plaid_access_token: 'access_token_logo_test2',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank',
      logo: Base64.strict_encode64('this is just text, not an image')
    )

    assert_not bank.valid?
    assert_includes bank.errors[:logo], 'must be a valid PNG, JPEG, or GIF image'
  end

  test 'is valid with valid PNG logo' do
    user = User.create!(
      first_name: 'Logo',
      last_name: 'User',
      email_address: 'logouser_valid@example.com',
      password: 'password'
    )

    # Valid 1x1 transparent PNG
    valid_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

    bank = Bank.new(
      user: user,
      name: 'Test Bank',
      plaid_item_id: 'item_logo_test3',
      plaid_access_token: 'access_token_logo_test3',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank',
      logo: valid_png
    )

    assert bank.valid?
  end

  test 'logo_data_uri returns nil when logo is blank' do
    bank = banks(:chase)
    bank.logo = nil

    assert_nil bank.logo_data_uri
  end

  test 'logo_data_uri returns nil for invalid base64' do
    bank = banks(:chase)
    bank.logo = 'not-valid-base64!!!'

    assert_nil bank.logo_data_uri
  end

  test 'logo_data_uri returns nil for non-image base64' do
    bank = banks(:chase)
    bank.logo = Base64.strict_encode64('this is just text')

    assert_nil bank.logo_data_uri
  end

  test 'logo_data_uri returns correct data URI for valid PNG' do
    bank = banks(:chase)
    valid_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
    bank.logo = valid_png

    assert_equal "data:image/png;base64,#{valid_png}", bank.logo_data_uri
  end
end
