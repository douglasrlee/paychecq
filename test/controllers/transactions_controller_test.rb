require 'test_helper'

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:johndoe))
  end

  test 'should get index' do
    get transactions_url

    assert_response :success
  end
end
