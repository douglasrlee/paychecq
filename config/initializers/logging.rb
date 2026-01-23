Rails.application.config.after_initialize do
  if Rails.env.local?
    stdout_logger = ActiveSupport::Logger.new($stdout)

    Rails.logger.broadcast_to(stdout_logger)

    SolidQueue.logger = Rails.logger
  else
    appsignal_logger = Appsignal::Logger.new('rails')

    Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
  end
end
