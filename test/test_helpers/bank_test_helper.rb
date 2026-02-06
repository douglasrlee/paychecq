module BankTestHelper
  def create_bank(email:, plaid_item_id:, status: 'healthy', plaid_error_code: nil)
    user = User.create!(first_name: 'Test', last_name: 'User', email_address: email, password: 'password')

    Bank.create!(
      user: user,
      name: 'Test Bank',
      plaid_item_id: plaid_item_id,
      plaid_access_token: 'access_token_test',
      plaid_institution_id: 'ins_999',
      plaid_institution_name: 'Test Bank',
      status: status,
      plaid_error_code: plaid_error_code
    )
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include BankTestHelper
end
