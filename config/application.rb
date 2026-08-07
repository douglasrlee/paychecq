require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PayChecQ
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use custom mail delivery job with retries
    config.action_mailer.delivery_job = 'MailDeliveryJob'

    # The app doesn't use ActiveStorage attachments/variants. Rails 8.1's
    # framework default (config.load_defaults 8.1) picks :vips, and since
    # Rails 8.1.3.1 that gets resolved eagerly at boot rather than lazily —
    # crashing on boot without the ruby-vips gem and the libvips system
    # library, neither of which this app has (or needs).
    config.active_storage.variant_processor = :disabled
  end
end
