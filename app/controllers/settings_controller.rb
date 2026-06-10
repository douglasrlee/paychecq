class SettingsController < ApplicationController
  TRANSACTION_NAME_OVERRIDES_PER_PAGE = 5

  def show
    @bank = Current.user.banks.includes(:bank_accounts).first
    @push_notifications_enabled = Current.user.push_subscriptions.exists?

    overrides_scope = Current.user.transaction_name_overrides.order(:match_type, :match_text)
    @transaction_name_overrides_total = overrides_scope.count
    @transaction_name_overrides_total_pages = [ (@transaction_name_overrides_total.to_f / TRANSACTION_NAME_OVERRIDES_PER_PAGE).ceil, 1 ].max
    @transaction_name_overrides_page = params[:page].to_i.clamp(1, @transaction_name_overrides_total_pages)
    @transaction_name_overrides = overrides_scope
                                  .limit(TRANSACTION_NAME_OVERRIDES_PER_PAGE)
                                  .offset((@transaction_name_overrides_page - 1) * TRANSACTION_NAME_OVERRIDES_PER_PAGE)
                                  .to_a

    if @bank
      if @bank.needs_attention? && !@bank.disconnected?
        @plaid_update_link_token = PlaidService.create_update_link_token(@bank)

        flash.now[:alert] = 'Unable to initialize bank reconnection. Please try again later.' unless @plaid_update_link_token
      end
    else
      @plaid_link_token = PlaidService.create_link_token(Current.user)

      flash.now[:alert] = 'Unable to initialize bank linking. Please try again later.' unless @plaid_link_token
    end
  end
end
