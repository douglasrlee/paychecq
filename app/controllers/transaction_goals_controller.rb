class TransactionGoalsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to transactions_path, alert: 'Not found' }
    end
  end

  rescue_from ActionController::ParameterMissing do
    respond_to do |format|
      format.turbo_stream { head :unprocessable_content }
      format.html { redirect_to transactions_path, alert: 'Pick a goal first.' }
    end
  end

  def create
    @transaction = Current.user.transactions.find(params.expect(:transaction_id))
    goal = Current.user.goals.find(params.expect(:goal_id))

    unless @transaction.amount.positive?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html do
          redirect_to transaction_path(@transaction),
                      alert: "Refunds and credits can't be linked to goals.",
                      status: :see_other
        end
      end
      return
    end

    GoalLinker.link(transaction: @transaction, goal: goal)
    respond_with_drawer
  end

  def destroy
    @transaction = Current.user.transactions.find(params.expect(:id))
    GoalLinker.unlink(transaction: @transaction)
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
