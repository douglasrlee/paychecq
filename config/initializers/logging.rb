# Only configure logging when running as a server (not tests, migrations, console, etc.)
return unless defined?(Rails::Server) || $PROGRAM_NAME.include?('puma') || $PROGRAM_NAME.include?('jobs')

if Rails.env.local?
  Rails.application.config.after_initialize do
    stdout_logger = ActiveSupport::Logger.new($stdout)

    Rails.logger.broadcast_to(stdout_logger)

    SolidQueue.logger = Rails.logger
  end
else
  Rails.application.config.after_initialize do
    appsignal_logger = Appsignal::Logger.new('rails')
    appsignal_logger.level = Rails.configuration.log_level

    stdout_logger = ActiveSupport::Logger.new($stdout)

    Rails.logger.broadcast_to(stdout_logger)
    Rails.logger.broadcast_to(appsignal_logger)

    SolidQueue.logger = Rails.logger
  end
end
