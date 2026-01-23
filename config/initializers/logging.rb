Rails.application.config.after_initialize do
  if Rails.env.local?
    stdout_logger = ActiveSupport::Logger.new($stdout)
    Rails.logger.broadcast_to(stdout_logger)
  else
    appsignal_logger = Appsignal::Logger.new('rails')
    appsignal_logger.level = Rails.logger.level
    Rails.logger.broadcast_to(appsignal_logger)
  end

  SolidQueue.logger = Rails.logger
  ActiveJob::Base.logger = Rails.logger
end
