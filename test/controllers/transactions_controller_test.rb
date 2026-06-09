require 'test_helper'

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test 'index requires authentication' do
    get transactions_url

    assert_redirected_to new_session_path
  end

  test 'index shows transactions' do
    Transaction.create!(name: 'Starbucks', amount: 4.33, date: Date.current, bank_account: bank_accounts(:chase_checking))
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'p', text: 'Starbucks'
    assert_select 'p', text: '$4.33'
  end

  test 'index shows empty state when no bank linked' do
    sign_in_as(users(:admin))

    get transactions_url

    assert_response :success
    assert_select 'p', text: 'No bank account linked'
    assert_select 'a', text: 'Link Account'
  end

  test 'index shows empty state when bank linked but no transactions' do
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'p', text: 'No transactions yet'
  end

  test 'index displays override name when an override matches' do
    Transaction.create!(name: 'TESTEXACT', amount: 5.50, date: Date.current, bank_account: bank_accounts(:chase_checking))
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'p', text: 'ExactRenamed'
  end

  test 'show requires authentication' do
    transaction = Transaction.create!(name: 'TESTEXACT', amount: 5.50, bank_account: bank_accounts(:chase_checking))

    get transaction_url(transaction)

    assert_redirected_to new_session_path
  end

  test 'show renders the transaction detail with applied override' do
    transaction = Transaction.create!(name: 'TESTEXACT', amount: 5.50, bank_account: bank_accounts(:chase_checking))
    sign_in_as(users(:johndoe))

    get transaction_url(transaction)

    assert_response :success
    assert_select 'h3', text: 'ExactRenamed'
  end

  test 'show close button links back to transactions index' do
    transaction = Transaction.create!(name: 'Standalone', amount: 5.00, bank_account: bank_accounts(:chase_checking))
    sign_in_as(users(:johndoe))

    get transaction_url(transaction)

    assert_response :success
    assert_select "a[href=\"#{transactions_path}\"][data-action='click->drawer#close']"
  end

  test 'show only finds transactions belonging to the current user' do
    other_user_account = bank_accounts(:wells_checking)
    transaction = Transaction.create!(name: 'Private', amount: 10.00, bank_account: other_user_account)
    sign_in_as(users(:johndoe))

    get transaction_url(transaction)

    assert_response :not_found
  end
end
