# frozen_string_literal: true

Rails.application.config.web_push = ActiveSupport::OrderedOptions.new
Rails.application.config.web_push.vapid_public_key = ENV.fetch("VAPID_PUBLIC_KEY", nil)
Rails.application.config.web_push.vapid_private_key = ENV.fetch("VAPID_PRIVATE_KEY", nil)
Rails.application.config.web_push.vapid_subject = ENV.fetch("VAPID_SUBJECT", "mailto:support@paychecq.com")
