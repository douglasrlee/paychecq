# frozen_string_literal: true

::ENV['BUNDLE_GEMFILE'] ||= ::File.expand_path('../Gemfile', __dir__)

# Speed up boot time by caching expensive operations.
require 'bootsnap/setup'
# Set up gems listed in the Gemfile.
require 'bundler/setup'
