module Webhooks
  class PlaidController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      body = request.body.read

      PlaidService.verify_webhook(body, request.headers['Plaid-Verification'])

      PlaidWebhookJob.perform_later(JSON.parse(body))

      head :ok
    rescue ::JWT::DecodeError, ::JWT::VerificationError, ::JWT::ExpiredSignature, Plaid::ApiError => error
      Rails.logger.warn("Plaid webhook verification failed: #{error.message}")
      Appsignal.send_error(error)

      head :unauthorized
    end
  end
end
