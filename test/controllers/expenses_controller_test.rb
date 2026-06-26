require 'test_helper'

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:johndoe)
    @schedule = funding_schedules(:paycheck)
  end

  test 'index requires authentication' do
    get expenses_url

    assert_redirected_to new_session_path
  end

  test 'index renders the expenses list' do
    sign_in_as(@user)

    get expenses_url

    assert_response :success
    assert_select 'p', text: 'Netflix'
    assert_select 'p', text: 'Car insurance'
  end

  test 'index without funding schedules shows the setup pointer' do
    sign_in_as(@user)
    @user.expenses.destroy_all
    @user.funding_schedules.destroy_all

    get expenses_url

    assert_response :success
    assert_select 'p', text: /Add a funding schedule first/i
    assert_select 'a[href=?]', settings_path, text: /go to settings/i
  end

  test 'new renders the form' do
    sign_in_as(@user)

    get new_expense_url

    assert_response :success
    assert_select 'form'
  end

  test 'create persists an expense' do
    sign_in_as(@user)

    assert_difference '@user.expenses.count', 1 do
      post expenses_url, params: {
        expense: {
          name: 'Spotify',
          amount: '9.99',
          cadence: 'monthly',
          due_on: '2026-03-15',
          funding_schedule_id: @schedule.id
        }
      }
    end

    assert_redirected_to expenses_path
    expense = @user.expenses.order(:created_at).last
    assert_equal 'Spotify', expense.name
    assert_equal 9.99, expense.amount.to_f
    assert_equal 'monthly', expense.cadence
    assert_equal Date.new(2026, 3, 15), expense.due_on
  end

  test 'create responds with turbo_stream that replaces the expenses frame' do
    sign_in_as(@user)

    post expenses_url,
         params: {
           expense: {
             name: 'Spotify',
             amount: '9.99',
             cadence: 'monthly',
             due_on: '2026-03-15',
             funding_schedule_id: @schedule.id
           }
         },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="expenses"/, response.body)
    assert_match(/Spotify/, response.body)
  end

  test 'create re-renders new on invalid input' do
    sign_in_as(@user)

    assert_no_difference '@user.expenses.count' do
      post expenses_url, params: {
        expense: { name: '', amount: '9.99', cadence: 'monthly', due_on: '2026-03-15', funding_schedule_id: @schedule.id }
      }
    end

    assert_response :unprocessable_content
  end

  test 'create with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)

    post expenses_url,
         params: {
           expense: { name: '', amount: '9.99', cadence: 'monthly', due_on: '2026-03-15', funding_schedule_id: @schedule.id }
         },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'create rejects a funding schedule that belongs to another user' do
    sign_in_as(@user)
    other_schedule = funding_schedules(:janes_paycheck)

    assert_no_difference '@user.expenses.count' do
      post expenses_url, params: {
        expense: {
          name: 'Spotify',
          amount: '9.99',
          cadence: 'monthly',
          due_on: '2026-03-15',
          funding_schedule_id: other_schedule.id
        }
      }
    end

    assert_response :unprocessable_content
  end

  test 'edit renders the form for the user-owned expense' do
    sign_in_as(@user)

    get edit_expense_url(expenses(:netflix))

    assert_response :success
    assert_select 'form'
  end

  test 'edit redirects when the expense belongs to another user' do
    sign_in_as(@user)

    get edit_expense_url(expenses(:janes_rent))

    assert_redirected_to expenses_path
  end

  test 'update persists changes' do
    sign_in_as(@user)
    expense = expenses(:netflix)

    patch expense_url(expense), params: {
      expense: {
        name: 'Netflix Premium',
        amount: '22.99',
        cadence: 'monthly',
        due_on: '2026-02-14',
        funding_schedule_id: @schedule.id
      }
    }

    assert_redirected_to expenses_path
    expense.reload
    assert_equal 'Netflix Premium', expense.name
    assert_equal 22.99, expense.amount.to_f
  end

  test 'update applies the allocated amount alongside expense changes' do
    sign_in_as(@user)
    expense = expenses(:netflix) # starts with an $8.00 funded allocation

    patch expense_url(expense), params: {
      expense: {
        name: 'Netflix Premium', amount: '22.99', cadence: 'monthly',
        due_on: '2026-02-14', funding_schedule_id: @schedule.id
      },
      allocated_amount: '5.00'
    }

    assert_redirected_to expenses_path
    assert_equal 'Netflix Premium', expense.reload.name
    assert_equal 5.00, expense.bucket_balance.to_f
  end

  test 'update with an allocated amount over free-to-spend re-renders with an error' do
    sign_in_as(@user)
    expense = expenses(:netflix)

    patch expense_url(expense),
          params: {
            expense: {
              name: 'Netflix', amount: '22.99', cadence: 'monthly',
              due_on: '2026-02-14', funding_schedule_id: @schedule.id
            },
            allocated_amount: '999999'
          },
          headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_match(/Free-to-Spend/, response.body)
    assert_equal 8.00, expense.reload.bucket_balance.to_f, 'bucket left untouched on error'
  end

  test 'update without an allocated amount leaves the bucket untouched' do
    sign_in_as(@user)
    expense = expenses(:netflix)
    ManualAllocator.set_balance(item: expense, amount: 12.00)

    patch expense_url(expense), params: {
      expense: {
        name: 'Netflix', amount: '22.99', cadence: 'monthly',
        due_on: '2026-02-14', funding_schedule_id: @schedule.id
      }
    }

    assert_redirected_to expenses_path
    assert_equal 12.00, expense.reload.bucket_balance.to_f
  end

  test 'update with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)
    expense = expenses(:netflix)

    patch expense_url(expense),
          params: {
            expense: { name: '', amount: '22.99', cadence: 'monthly', due_on: '2026-02-14', funding_schedule_id: @schedule.id }
          },
          headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'destroy removes the expense' do
    sign_in_as(@user)
    expense = expenses(:netflix)

    assert_difference '@user.expenses.count', -1 do
      delete expense_url(expense)
    end

    assert_redirected_to expenses_path
  end

  test 'destroy redirects when the expense belongs to another user' do
    sign_in_as(@user)
    expense = expenses(:janes_rent)

    assert_no_difference 'Expense.count' do
      delete expense_url(expense)
    end

    assert_redirected_to expenses_path
  end
end
