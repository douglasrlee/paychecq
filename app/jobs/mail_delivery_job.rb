class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
end
