require 'test_helper'

class TransactionExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:johndoe)
    @user.expenses.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @netflix  = @user.expenses.create!(name: 'Netflix', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    @transaction = Transaction.create!(name: 'NETFLIX', amount: 15.99, bank_account: bank_accounts(:chase_checking))
  end

  test 'create requires authentication' do
    post transaction_expenses_url, params: { transaction_id: @transaction.id, expense_id: @netflix.id }

    assert_redirected_to new_session_path
  end

  test 'create links the transaction to the expense and redirects' do
    sign_in_as(@user)

    post transaction_expenses_url, params: { transaction_id: @transaction.id, expense_id: @netflix.id }

    assert_redirected_to transaction_path(@transaction)
    assert_equal @netflix, @transaction.reload.expense
  end

  test 'create responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)

    post transaction_expenses_url,
         params: { transaction_id: @transaction.id, expense_id: @netflix.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end

  test 'create redirects when transaction belongs to another user' do
    sign_in_as(@user)
    other = Transaction.create!(name: 'WHATEVER', amount: 10, bank_account: bank_accounts(:wells_checking))

    post transaction_expenses_url, params: { transaction_id: other.id, expense_id: @netflix.id }

    assert_redirected_to transactions_path
  end

  test 'destroy unlinks the transaction and redirects' do
    sign_in_as(@user)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    delete transaction_expense_url(@transaction)

    assert_response :see_other
    assert_redirected_to transaction_path(@transaction)
    assert_nil @transaction.reload.expense
  end

  test 'destroy responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    delete transaction_expense_url(@transaction), headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end
end
