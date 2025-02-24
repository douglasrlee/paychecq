# frozen_string_literal: true

if ENV.key?('CI')
  require 'simplecov'
  require 'simplecov-cobertura'

  SimpleCov.start 'rails'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# Add more helper methods to be used by all tests here...
class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
