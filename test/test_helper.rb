ENV['RAILS_ENV'] ||= 'test'

if ENV['CI']
  require 'simplecov'
  require 'simplecov_json_formatter'
  require 'json'

  # Custom formatter that outputs relative paths
  class RelativePathJSONFormatter
    def format(result)
      root = SimpleCov.root
      data = {
        meta: { simplecov_version: SimpleCov::VERSION },
        coverage: result.files.each_with_object({}) do |file, hsh|
          relative_path = file.filename.sub("#{root}/", '')
          hsh[relative_path] = { lines: file.coverage_data['lines'] }
        end
      }

      json = JSON.pretty_generate(data)
      File.write(File.join(SimpleCov.coverage_dir, 'coverage.json'), json)
      puts 'Coverage JSON written with relative paths'
      json
    end
  end

  SimpleCov.start 'rails' do
    formatter RelativePathJSONFormatter
  end
end

require_relative '../config/environment'
require 'rails/test_help'

require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
