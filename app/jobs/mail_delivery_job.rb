class MailDeliveryJob < ActionMailer::MailDeliveryJob
  # Retry with longer intervals for SMTP outages
  # Attempts: 1min, 5min, 15min, 30min, 1hr, 2hr, 4hr (total ~8 hours)
  retry_on StandardError, attempts: 8, wait: lambda { |executions|
    [ 1, 5, 15, 30, 60, 120, 240 ].fetch(executions - 2, 240).minutes
  }
end
