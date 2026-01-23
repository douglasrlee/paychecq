if Rails.env.local?
  Rails.application.config.after_initialize do
    stdout_logger = ActiveSupport::Logger.new($stdout)

    Rails.logger.broadcast_to(stdout_logger)

    SolidQueue.logger = Rails.logger
  end
else
  appsignal_logger = Appsignal::Logger.new('rails')

  Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
end
