class PushNotificationService
  MAX_INDIVIDUAL_NOTIFICATIONS = 5

  def self.notify_new_transactions(user:, transactions:)
    return if transactions.empty?
    return unless vapid_configured?

    subscriptions = user.push_subscriptions

    return if subscriptions.empty?

    if transactions.size <= MAX_INDIVIDUAL_NOTIFICATIONS
      send_individual_notifications(subscriptions, transactions)
    else
      send_summary_notification(subscriptions, transactions.size)
    end
  end

  def self.send_individual_notifications(subscriptions, transactions)
    transactions.each do |transaction|
      payload = {
        title: 'New Transaction',
        body: "#{transaction.name} — #{ActiveSupport::NumberHelper.number_to_currency(transaction.amount)}",
        path: '/',
        tag: "transaction-#{transaction.id}"
      }.to_json

      subscriptions.each { |subscription| send_push(subscription, payload) }
    end
  end

  private_class_method :send_individual_notifications

  def self.send_summary_notification(subscriptions, count)
    payload = {
      title: 'New Transactions',
      body: "#{count} new transactions added.",
      path: '/',
      tag: 'transaction-sync'
    }.to_json

    subscriptions.each { |subscription| send_push(subscription, payload) }
  end

  private_class_method :send_summary_notification

  def self.send_push(subscription, payload)
    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        subject: Rails.application.config.web_push.vapid_subject,
        public_key: Rails.application.config.web_push.vapid_public_key,
        private_key: Rails.application.config.web_push.vapid_private_key
      },
      ttl: 60 * 60
    )
  rescue WebPush::ExpiredSubscription
    Rails.logger.info("Removing expired push subscription #{subscription.id}")
    subscription.destroy
  rescue WebPush::ResponseError => error
    Rails.logger.error("Push notification failed for subscription #{subscription.id}: #{error.message}")
    Appsignal.send_error(error)
  end

  private_class_method :send_push

  def self.vapid_configured?
    Rails.application.config.web_push.vapid_public_key.present? &&
      Rails.application.config.web_push.vapid_private_key.present?
  end

  private_class_method :vapid_configured?
end
