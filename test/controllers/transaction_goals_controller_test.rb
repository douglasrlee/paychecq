require 'test_helper'

class TransactionGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:johndoe)
    @user.expenses.destroy_all
    @user.goals.destroy_all
    @user.funding_schedules.destroy_all

    @schedule = @user.funding_schedules.create!(name: 'Paycheck', cadence: 'biweekly', start_date: Date.new(2026, 1, 1))
    @vacation = @user.goals.create!(name: 'Vacation', amount: 15.99, cadence: 'monthly', due_on: Date.new(2026, 2, 14), funding_schedule: @schedule)
    @transaction = Transaction.create!(name: 'HOTEL', amount: 15.99, bank_account: bank_accounts(:chase_checking))
  end

  test 'create requires authentication' do
    post transaction_goals_url, params: { transaction_id: @transaction.id, goal_id: @vacation.id }

    assert_redirected_to new_session_path
  end

  test 'create links the transaction to the goal and redirects' do
    sign_in_as(@user)
    fully_fund(@vacation)

    post transaction_goals_url, params: { transaction_id: @transaction.id, goal_id: @vacation.id }

    assert_redirected_to transaction_path(@transaction)
    assert_equal @vacation, @transaction.reload.goal
  end

  test 'create responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)
    fully_fund(@vacation)

    post transaction_goals_url,
         params: { transaction_id: @transaction.id, goal_id: @vacation.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end

  test 'linking a goal shows the linked bucket card with an unlink action' do
    sign_in_as(@user)
    fully_fund(@vacation)

    post transaction_goals_url,
         params: { transaction_id: @transaction.id, goal_id: @vacation.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/Vacation/, response.body)
    assert_match(/Unlink/, response.body)
    assert_no_match(/Search expenses and goals/, response.body)
  end

  test 'create rejects a non-positive (refund/credit) transaction' do
    sign_in_as(@user)
    fully_fund(@vacation)
    credit = Transaction.create!(name: 'REFUND', amount: -15.99, bank_account: bank_accounts(:chase_checking))

    post transaction_goals_url, params: { transaction_id: credit.id, goal_id: @vacation.id }

    assert_response :see_other
    assert_match(/refunds and credits/i, flash[:alert])
    assert_nil credit.reload.goal
  end

  test 'create links an under-funded goal, drawing down whatever is available' do
    sign_in_as(@user)
    # @vacation has no funded allocations -> bucket_balance is 0. Linking is no
    # longer gated on being fully funded; it links and draws what's there (0).

    post transaction_goals_url,
         params: { transaction_id: @transaction.id, goal_id: @vacation.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_equal @vacation, @transaction.reload.goal
  end

  test 'create without goal_id responds gracefully via turbo_stream' do
    sign_in_as(@user)

    post transaction_goals_url,
         params: { transaction_id: @transaction.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
  end

  test 'create without goal_id redirects to transactions for an html submit' do
    sign_in_as(@user)

    post transaction_goals_url, params: { transaction_id: @transaction.id }

    assert_redirected_to transactions_path
    assert_match(/pick a goal first/i, flash[:alert])
  end

  test 'create redirects when transaction belongs to another user' do
    sign_in_as(@user)
    fully_fund(@vacation)
    other = Transaction.create!(name: 'WHATEVER', amount: 10, bank_account: bank_accounts(:wells_checking))

    post transaction_goals_url, params: { transaction_id: other.id, goal_id: @vacation.id }

    assert_redirected_to transactions_path
  end

  test 'destroy unlinks the transaction and redirects' do
    sign_in_as(@user)
    fully_fund(@vacation)
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    delete transaction_goal_url(@transaction)

    assert_response :see_other
    assert_redirected_to transaction_path(@transaction)
    assert_nil @transaction.reload.goal
  end

  test 'create re-renders the free-to-spend header with the updated total' do
    sign_in_as(@user)
    fully_fund(@vacation)

    post transaction_goals_url,
         params: { transaction_id: @transaction.id, goal_id: @vacation.id },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="free_to_spend"/, response.body)
    # Vacation's $15.99 bucket is now spent → $0 in buckets.
    assert_match(/\$0\.00 in buckets/, response.body)
  end

  test 'destroy responds with turbo_stream replacing drawer_content' do
    sign_in_as(@user)
    fully_fund(@vacation)
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    delete transaction_goal_url(@transaction), headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_content"/, response.body)
  end

  test 'destroy re-renders the free-to-spend header with the restored total' do
    sign_in_as(@user)
    fully_fund(@vacation)
    GoalLinker.link(transaction: @transaction, goal: @vacation)

    delete transaction_goal_url(@transaction), headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="free_to_spend"/, response.body)
    # Unlinking restores Vacation's $15.99 to its bucket.
    assert_match(/\$15\.99 in buckets/, response.body)
  end

  private

  def fully_fund(goal)
    event = goal.funding_schedule.funding_events.create!(occurs_on: Date.new(2026, 1, 1))
    Allocation.create!(funding_event: event, goal: goal, amount: goal.amount, funded_at: Time.current)
  end
end
