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
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Give each parallel worker a unique SimpleCov command name for proper coverage merging
    parallelize_setup do |worker|
      SimpleCov.command_name "test-#{worker}" if defined?(SimpleCov)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
