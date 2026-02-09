class TransactionsController < ApplicationController
  def index
    @transactions = Current.user.transactions.order(Arel.sql('date DESC NULLS LAST, created_at DESC')).load
    @has_bank = Current.user.banks.exists? if @transactions.empty?
  end
end
