class TransactionNameOverridesController < ApplicationController
  before_action :set_override, only: [ :destroy ]

  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to settings_path }
    end
  end

  def create
    @override = Current.user.transaction_name_overrides.new(override_params)

    if @override.save
      @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
      @matching_transactions = matching_transactions(@override)
      load_transaction_for_drawer

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to transactions_path, status: :see_other }
      end
    else
      redirect_to safe_return_path, status: :see_other, alert: @override.errors.full_messages.to_sentence
    end
  end

  def destroy
    @matching_transactions = matching_transactions(@override) if params[:transaction_id].present?
    @override.destroy

    if params[:transaction_id].present?
      @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
      load_transaction_for_drawer
    else
      @transaction_name_overrides_pagy, @transaction_name_overrides = pagy(
        Current.user.transaction_name_overrides.order(:match_type, :match_text),
        request_path: settings_path
      )
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to safe_return_path, status: :see_other }
    end
  end

  private

  def set_override
    @override = Current.user.transaction_name_overrides.find(params[:id])
  end

  def override_params
    params.expect(transaction_name_override: [ :match_type, :match_text, :replacement_name ])
  end

  def load_transaction_for_drawer
    return if params[:transaction_id].blank?

    @transaction = Current.user.transactions.includes(:bank_account).find(params[:transaction_id])
    @transaction_name_override = @transaction.applied_override(@transaction_name_overrides)
  end

  def matching_transactions(override)
    transactions = Current.user.transactions
    case override.match_type
    when 'exact'
      transactions.where('LOWER(transactions.name) = LOWER(?)', override.match_text)
    when 'contains'
      transactions.where('LOWER(transactions.name) LIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(override.match_text.downcase)}%")
    end
  end

  def safe_return_path
    return_to = params[:return_to].to_s
    return_to.start_with?('/') && !return_to.start_with?('//') ? return_to : settings_path
  end
end
