class TransactionsController < ApplicationController
  def index
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transactions_pagy, @transactions = pagy(
      Current.user.transactions.order(Arel.sql('date DESC NULLS LAST, created_at DESC')),
      limit: 25
    )
    @has_bank = Current.user.banks.exists?
    @available_balance = Current.user.bank_accounts.sum(:available_balance) if @has_bank
  end

  def show
    @transaction = Current.user.transactions.find(params.expect(:id))
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transaction_name_override = @transaction.applied_override(@transaction_name_overrides)
  end
end
