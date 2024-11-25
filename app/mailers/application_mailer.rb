# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'support@paychecq.com'
  layout 'mailer'
end
