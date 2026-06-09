class TransactionsController < ApplicationController
  def index
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transactions = Current.user.transactions.order(Arel.sql('date DESC NULLS LAST, created_at DESC')).load
    @has_bank = Current.user.banks.exists? if @transactions.empty?
  end

  def show
    @transaction = Current.user.transactions.includes(:bank_account).find(params[:id])
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transaction_name_override = find_transaction_name_override(@transaction, @transaction_name_overrides)
  end

  private

  def find_transaction_name_override(transaction, transaction_name_overrides)
    transaction_name_overrides.find { |o| o.match_type == 'exact' && transaction.name.casecmp?(o.match_text) } ||
      transaction_name_overrides.find { |o| o.match_type == 'contains' && transaction.name.downcase.include?(o.match_text.downcase) }
  end
end
