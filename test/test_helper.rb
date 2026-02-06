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
require 'webmock/minitest'

require_relative 'test_helpers/session_test_helper'
require_relative 'test_helpers/bank_test_helper'

# Allow localhost connections for system tests
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Configure SimpleCov for parallel test coverage merging
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" if defined?(SimpleCov)
    end

    parallelize_teardown do |_worker|
      SimpleCov.result if defined?(SimpleCov)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
