# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: '"PayChecQ" <support@paychecq.com>'

  layout 'mailer'
end
