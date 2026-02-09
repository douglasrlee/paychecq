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
end
