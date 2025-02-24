# frozen_string_literal: true

require 'test_helper'

class HealthsControllerTest < ActionDispatch::IntegrationTest
  test 'should get index' do
    get '/health'

    assert_response :success
  end
end
