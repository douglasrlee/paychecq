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

  test 'index paginates transactions at 25 per page' do
    account = bank_accounts(:chase_checking)
    30.times do |i|
      Transaction.create!(name: "Txn #{i}", amount: 1.00 + i, date: Date.current - i.days, bank_account: account)
    end
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'p', text: 'Txn 0'
    assert_select 'p', text: 'Txn 24'
    assert_select 'p', text: 'Txn 25', count: 0
    assert_select 'a', text: /Next/
  end

  test 'index second page shows the next batch of transactions' do
    account = bank_accounts(:chase_checking)
    30.times do |i|
      Transaction.create!(name: "Txn #{i}", amount: 1.00 + i, date: Date.current - i.days, bank_account: account)
    end
    sign_in_as(users(:johndoe))

    get transactions_url(page: 2)

    assert_response :success
    assert_select 'p', text: 'Txn 25'
    assert_select 'p', text: 'Txn 29'
    assert_select 'p', text: 'Txn 0', count: 0
    assert_select 'a', text: /Prev/
  end

  test 'index shows aggregated available balance when a bank is linked' do
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'span', text: 'Available Balance:'
    assert_select 'span', text: '$6,000.00'
  end

  test 'index does not render an available balance when no bank is linked' do
    sign_in_as(users(:admin))

    get transactions_url

    assert_response :success
    assert_select 'span', text: 'Available Balance:', count: 0
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

  test 'show does not render a duplicate drawer_content frame in the layout' do
    transaction = Transaction.create!(name: 'Solo', amount: 10.00, bank_account: bank_accounts(:chase_checking))
    sign_in_as(users(:johndoe))

    get transaction_url(transaction)

    assert_response :success
    assert_select 'turbo-frame[id=drawer_content]', count: 1
  end

  test 'index renders an empty drawer_content frame in the layout' do
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
    assert_select 'turbo-frame[id=drawer_content]', count: 1
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
