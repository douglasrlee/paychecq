require 'test_helper'

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test 'index requires authentication' do
    get transactions_url

    assert_redirected_to new_session_path
  end

  test 'index shows transactions' do
    sign_in_as(users(:johndoe))

    get transactions_url

    assert_response :success
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
