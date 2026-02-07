class PushSubscriptionsController < ApplicationController
  def create
    subscription_data = params.expect(push_subscription: [ :endpoint, { keys: [ :p256dh, :auth ] } ])

    push_subscription = Current.user.push_subscriptions.find_or_initialize_by(
      endpoint: subscription_data[:endpoint]
    )
    push_subscription.assign_attributes(
      p256dh_key: subscription_data.dig(:keys, :p256dh),
      auth_key: subscription_data.dig(:keys, :auth)
    )

    if push_subscription.save
      head :created
    else
      head :unprocessable_content
    end
  end

  def destroy
    Current.user.push_subscriptions.find_by(endpoint: params[:endpoint])&.destroy

    head :ok
  end
end
