# frozen_string_literal: true

require 'application_system_test_case'

class HealthsTest < ApplicationSystemTestCase
  test 'visiting the index' do
    visit '/health'

    assert_selector 'body', style: 'background-color: green'
  end
end
