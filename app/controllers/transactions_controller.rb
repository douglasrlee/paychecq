class TransactionsController < ApplicationController
  def index
    @transactions = Current.user.transactions.order(Arel.sql("date DESC NULLS LAST, created_at DESC"))
    @has_bank = Current.user.banks.exists?
  end
end
