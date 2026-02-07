class SendPushNotificationJob < ApplicationJob
  def perform(user_id, transaction_ids)
    user = User.find_by(id: user_id)

    return unless user

    transactions = Transaction.where(id: transaction_ids)

    return if transactions.empty?

    PushNotificationService.notify_new_transactions(user: user, transactions: transactions)
  end
end
