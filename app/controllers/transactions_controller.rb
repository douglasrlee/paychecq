class TransactionsController < ApplicationController
  def index
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transactions_pagy, @transactions = pagy(
      Current.user.transactions.includes(:expense).order(Arel.sql('date DESC NULLS LAST, created_at DESC')),
      limit: 25
    )
    # Free-to-Spend (available balance minus funded buckets) is computed in
    # the transactions/_free_to_spend partial so the link/unlink streams can
    # re-render it.
    @has_bank = Current.user.banks.exists?
  end

  def show
    @transaction = Current.user.transactions.find(params.expect(:id))
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transaction_name_override = @transaction.applied_override(@transaction_name_overrides)
  end
end
