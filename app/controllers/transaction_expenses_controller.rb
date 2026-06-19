class TransactionExpensesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to transactions_path, alert: 'Not found'
  end

  # Saving the form without picking an expense (the picker UI prevents this
  # via a disabled submit, but a stray turbo request without expense_id
  # would otherwise raise ParameterMissing). For turbo_stream we return
  # 422 no-op; for HTML we redirect to the transactions index with an
  # alert (we may not have a valid transaction in scope to redirect to).
  rescue_from ActionController::ParameterMissing do
    respond_to do |format|
      format.turbo_stream { head :unprocessable_content }
      format.html { redirect_to transactions_path, alert: 'Pick an expense first.' }
    end
  end

  def create
    @transaction = Current.user.transactions.find(params.expect(:transaction_id))
    expense = Current.user.expenses.find(params.expect(:expense_id))

    unless expense.fully_funded?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html do
          redirect_to transaction_path(@transaction),
                      alert: "#{expense.name} isn't fully funded yet.",
                      status: :see_other
        end
      end
      return
    end

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
