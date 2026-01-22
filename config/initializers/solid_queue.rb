# Log to STDOUT when running Solid Queue standalone (not via Puma plugin)
# Set SOLID_QUEUE_LOG_STDOUT=1 to enable
if ENV['SOLID_QUEUE_adfLOG_STDOUT']
  Rails.application.config.after_initialize do
    stdout_logger = ActiveSupport::Logger.new($stdout)
    Rails.logger.broadcast_to(stdout_logger)
    ActiveRecord::Base.logger.broadcast_to(stdout_logger)
    SolidQueue.logger = Rails.logger
  end
end
