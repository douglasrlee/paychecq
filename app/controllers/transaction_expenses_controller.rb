class TransactionExpensesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to transactions_path, alert: 'Not found'
  end

  def create
    @transaction = Current.user.transactions.find(params.expect(:transaction_id))
    expense = Current.user.expenses.find(params.expect(:expense_id))
    ExpenseLinker.link(transaction: @transaction, expense: expense)
    respond_with_drawer
  end

  def destroy
    @transaction = Current.user.transactions.find(params.expect(:id))
    ExpenseLinker.unlink(transaction: @transaction)
    respond_with_drawer
  end

  private

  def respond_with_drawer
    @transaction_name_overrides = Current.user.transaction_name_overrides.to_a
    @transaction_name_override = @transaction.applied_override(@transaction_name_overrides)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to transaction_path(@transaction), status: :see_other }
    end
  end
end
