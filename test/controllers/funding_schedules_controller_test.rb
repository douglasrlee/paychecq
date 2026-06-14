require 'test_helper'

class FundingSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'new requires authentication' do
    get new_funding_schedule_url

    assert_redirected_to new_session_path
  end

  test 'new renders the form' do
    sign_in_as(@user)

    get new_funding_schedule_url

    assert_response :success
    assert_select 'form'
  end

  test 'create persists a biweekly schedule' do
    sign_in_as(@user)

    assert_difference '@user.funding_schedules.count', 1 do
      post funding_schedules_url, params: {
        funding_schedule: { name: 'Paycheck 2', cadence: 'biweekly', start_date: '2026-02-05' }
      }
    end

    assert_redirected_to settings_path
    schedule = @user.funding_schedules.order(:created_at).last
    assert_equal 'biweekly', schedule.cadence
    assert_equal Date.new(2026, 2, 5), schedule.start_date
  end

  test 'create responds with turbo_stream that replaces the settings list' do
    sign_in_as(@user)

    post funding_schedules_url,
         params: { funding_schedule: { name: 'Paycheck 2', cadence: 'biweekly', start_date: '2026-02-05' } },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="funding_schedules"/, response.body)
    assert_match(/Paycheck 2/, response.body)
  end

  test 'create persists a semimonthly schedule with second day' do
    sign_in_as(@user)

    post funding_schedules_url, params: {
      funding_schedule: { name: 'Twice monthly', cadence: 'semimonthly', start_date: '2026-02-01', second_day_of_month: '15' }
    }

    assert_redirected_to settings_path
    schedule = @user.funding_schedules.order(:created_at).last
    assert_equal 'semimonthly', schedule.cadence
    assert_equal 15, schedule.second_day_of_month
  end

  test 'create strips second_day_of_month when cadence is not semimonthly' do
    sign_in_as(@user)

    assert_difference '@user.funding_schedules.count', 1 do
      post funding_schedules_url, params: {
        funding_schedule: { name: 'Weekly', cadence: 'weekly', start_date: '2026-02-05', second_day_of_month: '15' }
      }
    end

    assert_redirected_to settings_path
    schedule = @user.funding_schedules.order(:created_at).last
    assert_nil schedule.second_day_of_month
  end

  test 'create re-renders new on invalid input' do
    sign_in_as(@user)

    assert_no_difference '@user.funding_schedules.count' do
      post funding_schedules_url, params: {
        funding_schedule: { name: '', cadence: 'biweekly', start_date: '2026-02-05' }
      }
    end

    assert_response :unprocessable_content
  end

  test 'create with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)

    post funding_schedules_url,
         params: { funding_schedule: { name: '', cadence: 'biweekly', start_date: '2026-02-05' } },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'edit renders the form for the user-owned schedule' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck)

    get edit_funding_schedule_url(schedule)

    assert_response :success
    assert_select 'form'
  end

  test 'edit redirects when the schedule belongs to another user' do
    sign_in_as(@user)
    schedule = funding_schedules(:janes_paycheck)

    get edit_funding_schedule_url(schedule)

    assert_redirected_to settings_path
  end

  test 'update persists changes' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck)

    patch funding_schedule_url(schedule), params: {
      funding_schedule: { name: 'Renamed', cadence: 'biweekly', start_date: '2026-01-01' }
    }

    assert_redirected_to settings_path
    assert_equal 'Renamed', schedule.reload.name
  end

  test 'update responds with turbo_stream that replaces the settings list' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck)

    patch funding_schedule_url(schedule),
          params: { funding_schedule: { name: 'Renamed', cadence: 'biweekly', start_date: '2026-01-01' } },
          headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="funding_schedules"/, response.body)
    assert_match(/Renamed/, response.body)
  end

  test 'update re-renders edit on invalid input' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck)

    patch funding_schedule_url(schedule), params: {
      funding_schedule: { name: '', cadence: 'biweekly', start_date: '2026-01-01' }
    }

    assert_response :unprocessable_content
  end

  test 'update with turbo_stream accept and invalid input returns html form' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck)

    patch funding_schedule_url(schedule),
          params: { funding_schedule: { name: '', cadence: 'biweekly', start_date: '2026-01-01' } },
          headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :unprocessable_content
    assert_select 'form'
  end

  test 'destroy removes the schedule' do
    sign_in_as(@user)
    schedule = funding_schedules(:side_gig) # no expenses attached

    assert_difference '@user.funding_schedules.count', -1 do
      delete funding_schedule_url(schedule)
    end

    assert_redirected_to settings_path
  end

  test 'destroy redirects when the schedule belongs to another user' do
    sign_in_as(@user)
    schedule = funding_schedules(:janes_paycheck)

    assert_no_difference 'FundingSchedule.count' do
      delete funding_schedule_url(schedule)
    end

    assert_redirected_to settings_path
  end

  test 'destroy is blocked when expenses are tied to the schedule' do
    sign_in_as(@user)
    schedule = funding_schedules(:paycheck) # has Netflix + Car insurance fixtures

    assert_no_difference 'FundingSchedule.count' do
      delete funding_schedule_url(schedule)
    end

    follow_redirect!
    assert_match(/dependent expenses/i, flash[:alert] || @response.body)
  end
end
