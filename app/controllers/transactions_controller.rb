class TransactionsController < ApplicationController
  def index
    @transactions = Current.user.transactions.order(date: :desc, created_at: :desc)
    @has_bank = Current.user.banks.exists?
  end
end
