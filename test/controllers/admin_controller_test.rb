require 'test_helper'

class AdminControllerTest < ActionDispatch::IntegrationTest
  test 'unauthenticated user is redirected to login' do
    get '/jobs'

    assert_redirected_to '/session/new'
  end

  test 'non-admin user is redirected to root' do
    sign_in_as(users(:johndoe))

    get '/jobs'

    assert_redirected_to '/'
    assert_equal 'Not authorized', flash[:alert]
  end

  test 'admin user can access jobs' do
    sign_in_as(users(:admin))

    get '/jobs'

    assert_response :success
  end
end
