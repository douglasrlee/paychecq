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
    fully_fund(@netflix)

    post transaction_expenses_url, params: { transaction_id: @transaction.id, expense_id: @netflix.id }

    assert_redirected_to transaction_path(@transaction)
    assert_equal @netflix, @transaction.reload.expense
  end

  test 'create responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)
    fully_fund(@netflix)

    post transaction_expenses_url,
         params: { transaction_id: @transaction.id, expense_id: @netflix.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end

  test 'create rejects a non-positive (refund/credit) transaction' do
    sign_in_as(@user)
    fully_fund(@netflix)
    credit = Transaction.create!(name: 'REFUND', amount: -15.99, bank_account: bank_accounts(:chase_checking))

    post transaction_expenses_url, params: { transaction_id: credit.id, expense_id: @netflix.id }

    assert_response :see_other
    assert_match(/refunds and credits/i, flash[:alert])
    assert_nil credit.reload.expense
  end

  test 'create rejects an under-funded expense' do
    sign_in_as(@user)
    # @netflix has no funded allocations -> bucket_balance is 0 -> not fully funded

    post transaction_expenses_url, params: { transaction_id: @transaction.id, expense_id: @netflix.id }

    assert_response :see_other
    assert_match(/isn't fully funded/i, flash[:alert])
    assert_nil @transaction.reload.expense
  end

  test 'create without expense_id responds gracefully via turbo_stream' do
    sign_in_as(@user)

    post transaction_expenses_url,
         params: { transaction_id: @transaction.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
  end

  test 'create without expense_id redirects to transactions for an html submit' do
    sign_in_as(@user)

    post transaction_expenses_url, params: { transaction_id: @transaction.id }

    assert_redirected_to transactions_path
    assert_match(/pick an expense first/i, flash[:alert])
  end

  test 'create redirects when transaction belongs to another user' do
    sign_in_as(@user)
    other = Transaction.create!(name: 'WHATEVER', amount: 10, bank_account: bank_accounts(:wells_checking))

    post transaction_expenses_url, params: { transaction_id: other.id, expense_id: @netflix.id }

    assert_redirected_to transactions_path
  end

  test 'destroy unlinks the transaction and redirects' do
    sign_in_as(@user)
    fully_fund(@netflix)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    delete transaction_expense_url(@transaction)

    assert_response :see_other
    assert_redirected_to transaction_path(@transaction)
    assert_nil @transaction.reload.expense
  end

  test 'create re-renders the free-to-spend header with the updated total' do
    sign_in_as(@user)
    fully_fund(@netflix)

    post transaction_expenses_url,
         params: { transaction_id: @transaction.id, expense_id: @netflix.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="free_to_spend"/, response.body)
    # Netflix's $15.99 bucket is now spent → $0 in buckets, full $6,000 free.
    assert_match(/\$0\.00 in buckets/, response.body)
  end

  test 'destroy responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)
    fully_fund(@netflix)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    delete transaction_expense_url(@transaction), headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end

  test 'destroy re-renders the free-to-spend header with the restored total' do
    sign_in_as(@user)
    fully_fund(@netflix)
    ExpenseLinker.link(transaction: @transaction, expense: @netflix)

    delete transaction_expense_url(@transaction), headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="free_to_spend"/, response.body)
    # Unlinking restores Netflix's $15.99 to its bucket.
    assert_match(/\$15\.99 in buckets/, response.body)
  end

  private

  def fully_fund(expense)
    event = expense.funding_schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: event, expense: expense, amount: expense.amount, funded_at: Time.current)
  end
end
