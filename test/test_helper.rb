ENV['RAILS_ENV'] ||= 'test'

if ENV['CI']
  require 'simplecov'
  require 'simplecov-cobertura'

  SimpleCov.start 'rails' do
    formatter SimpleCov::Formatter::CoberturaFormatter
  end
end

require_relative '../config/environment'
require 'rails/test_help'

require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Disable parallel testing in CI for accurate coverage merging
    if ENV['CI']
      parallelize(workers: 1)
    else
      parallelize(workers: :number_of_processors)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
