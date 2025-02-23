# frozen_string_literal: true

class ActiveSupport::TestCase
  def before_setup
    Bullet.start_request

    super
  end

  def after_teardown
    super

    Bullet.perform_out_of_channel_notifications if Bullet.notification?
    Bullet.end_request
  end
end
