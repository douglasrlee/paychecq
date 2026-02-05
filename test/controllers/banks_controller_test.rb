require 'test_helper'

class BanksControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'create requires authentication' do
    post banks_path, params: { public_token: 'test-token' }

    assert_redirected_to new_session_path
  end

  test 'create redirects with error on Plaid API failure' do
    sign_in_as(@user)

    # Without valid Plaid credentials, this will fail
    post banks_path, params: {
      public_token: 'invalid-token',
      institution_id: 'ins_1',
      institution_name: 'Test Bank'
    }

    assert_redirected_to settings_path
    assert_equal 'Failed to link bank account. Please try again.', flash[:alert]
  end

  test 'destroy requires authentication' do
    bank = banks(:chase)

    delete bank_path(bank)

    assert_redirected_to new_session_path
  end

  test 'destroy removes bank and redirects' do
    sign_in_as(@user)
    bank = Bank.create!(
      user: @user,
      name: 'Test Bank',
      plaid_item_id: 'item_destroy_test',
      plaid_access_token: 'access_token_destroy_test',
      plaid_institution_id: 'ins_1',
      plaid_institution_name: 'Test Institution'
    )

    assert_difference('Bank.count', -1) do
      delete bank_path(bank)
    end

    assert_redirected_to settings_path
    assert_equal 'Bank account deleted successfully.', flash[:notice]
  end

  test 'destroy cannot delete another users bank' do
    sign_in_as(@user)
    other_user = users(:janedoe)
    other_user_bank = Bank.create!(
      user: other_user,
      name: 'Other User Bank',
      plaid_item_id: 'item_other_user',
      plaid_access_token: 'access_token_other_user',
      plaid_institution_id: 'ins_2',
      plaid_institution_name: 'Other Bank'
    )

    assert_no_difference('Bank.count') do
      delete bank_path(other_user_bank)
    end

    assert_response :not_found
  end
end
