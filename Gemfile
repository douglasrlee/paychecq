source 'https://rubygems.org'

ruby '4.0.1'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.2'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem 'jsbundling-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem 'cssbundling-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt', '~> 3.1.7'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [ :windows, :jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem 'solid_cable'
gem 'solid_cache'
gem 'solid_queue'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

# Catch unsafe migrations in development [https://github.com/ankane/strong_migrations]
gem 'strong_migrations'

# Track changes to your models, for auditing or versioning. [https://github.com/paper-trail-gem/paper_trail]
gem 'paper_trail'

# MJML-Rails allows you to render HTML emails from an MJML template. [https://github.com/sighmon/mjml-rails]
gem 'mjml-rails'
gem 'mrml'

# To provide more visibility into the Ruby runtime on Heroku [https://devcenter.heroku.com/articles/language-runtime-metrics-ruby#getting-started]
gem 'barnes'

# Application monitoring [appsignal.com]
gem 'appsignal'

# The ostruct gem provides the OpenStruct class, which lets you create objects with arbitrary attributes (required for appsignal)
gem 'ostruct'

# Send emails with Mailgun
gem 'mailgun-ruby', '~>1.4.1'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: [ :mri, :windows ], require: 'debug/prelude'

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # A RuboCop extension focused on enforcing Rails best practices and coding conventions. [https://github.com/rubocop/rubocop-rails]
  gem 'rubocop-rails', require: false

  # Capybara-specific analysis for your projects, as an extension to RuboCop. [https://github.com/rubocop/rubocop-capybara]
  gem 'rubocop-capybara', require: false

  # The Bullet gem is designed to help you increase your application's performance by reducing the number of queries it makes. [https://github.com/flyerhzm/bullet]
  gem 'bullet'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'

  # Code coverage
  'simplecov'
end
