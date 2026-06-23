require 'test_helper'

class GoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:johndoe)
    @schedule = funding_schedules(:paycheck)
    @goal = @user.goals.create!(
      name: 'Vacation', amount: 1200.00, cadence: 'yearly',
      due_on: Date.new(2026, 12, 1), funding_schedule: @schedule
    )
  end

  test 'index requires authentication' do
    get goals_url

    assert_redirected_to new_session_path
  end

  test 'index renders the goals list' do
    sign_in_as(@user)

    get goals_url

    assert_response :success
    assert_select 'p', text: 'Vacation'
  end

  test 'index without funding schedules shows the setup pointer' do
    sign_in_as(@user)
    @user.expenses.destroy_all
    @user.goals.destroy_all
    @user.funding_schedules.destroy_all

    get goals_url

    assert_response :success
    assert_select 'p', text: /Add a funding schedule first/i
    assert_select 'a[href=?]', settings_path, text: /go to settings/i
  end

  test 'new renders the form' do
    sign_in_as(@user)

    get new_goal_url

    assert_response :success
    assert_select 'form'
  end

  test 'create persists a goal' do
    sign_in_as(@user)

    assert_difference '@user.goals.count', 1 do
      post goals_url, params: {
        goal: {
          name: 'New car',
          amount: '5000.00',
          cadence: 'yearly',
          due_on: '2027-01-01',
          funding_schedule_id: @schedule.id
        }
      }
    end

    assert_redirected_to goals_path
    goal = @user.goals.order(:created_at).last
    assert_equal 'New car', goal.name
    assert_equal 5000.00, goal.amount.to_f
    assert_equal 'yearly', goal.cadence
    assert_equal Date.new(2027, 1, 1), goal.due_on
  end

  test 'create responds with turbo_stream that replaces the goals frame' do
    sign_in_as(@user)

    post goals_url,
         params: {
           goal: {
             name: 'New car',
             amount: '5000.00',
             cadence: 'yearly',
             due_on: '2027-01-01',
             funding_schedule_id: @schedule.id
           }
         },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="goals"/, response.body)
    assert_match(/New car/, response.body)
  end

  test 'create re-renders new on invalid input' do
    sign_in_as(@user)

    assert_no_difference '@user.goals.count' do
      post goals_url, params: {
        goal: { name: '', amount: '5000.00', cadence: 'yearly', due_on: '2027-01-01', funding_schedule_id: @schedule.id }
      }
    end

    assert_response :unprocessable_content
  end

  test 'create with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)

    post goals_url,
         params: {
           goal: { name: '', amount: '5000.00', cadence: 'yearly', due_on: '2027-01-01', funding_schedule_id: @schedule.id }
         },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'create rejects a funding schedule that belongs to another user' do
    sign_in_as(@user)
    other_schedule = funding_schedules(:janes_paycheck)

    assert_no_difference '@user.goals.count' do
      post goals_url, params: {
        goal: {
          name: 'New car',
          amount: '5000.00',
          cadence: 'yearly',
          due_on: '2027-01-01',
          funding_schedule_id: other_schedule.id
        }
      }
    end

    assert_response :unprocessable_content
  end

  test 'edit renders the form for the user-owned goal' do
    sign_in_as(@user)

    get edit_goal_url(@goal)

    assert_response :success
    assert_select 'form'
  end

  test 'edit redirects when the goal belongs to another user' do
    sign_in_as(@user)
    janes_goal = users(:janedoe).goals.create!(
      name: 'Janes goal', amount: 100, cadence: 'yearly',
      due_on: Date.new(2026, 10, 1), funding_schedule: funding_schedules(:janes_paycheck)
    )

    get edit_goal_url(janes_goal)

    assert_redirected_to goals_path
  end

  test 'update persists changes' do
    sign_in_as(@user)

    patch goal_url(@goal), params: {
      goal: {
        name: 'Big vacation',
        amount: '2200.00',
        cadence: 'yearly',
        due_on: '2026-12-01',
        funding_schedule_id: @schedule.id
      }
    }

    assert_redirected_to goals_path
    @goal.reload
    assert_equal 'Big vacation', @goal.name
    assert_equal 2200.00, @goal.amount.to_f
  end

  test 'update with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)

    patch goal_url(@goal),
          params: {
            goal: { name: '', amount: '2200.00', cadence: 'yearly', due_on: '2026-12-01', funding_schedule_id: @schedule.id }
          },
          headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'destroy removes the goal' do
    sign_in_as(@user)

    assert_difference '@user.goals.count', -1 do
      delete goal_url(@goal)
    end

    assert_redirected_to goals_path
  end

  test 'destroy redirects when the goal belongs to another user' do
    sign_in_as(@user)
    janes_goal = users(:janedoe).goals.create!(
      name: 'Janes goal', amount: 100, cadence: 'yearly',
      due_on: Date.new(2026, 10, 1), funding_schedule: funding_schedules(:janes_paycheck)
    )

    assert_no_difference 'Goal.count' do
      delete goal_url(janes_goal)
    end

    assert_redirected_to goals_path
  end
end
