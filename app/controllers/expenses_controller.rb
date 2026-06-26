class ExpensesController < ApplicationController
  before_action :set_expense, only: [ :edit, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to expenses_path, alert: 'Expense not found'
  end

  def index
    @expenses = Current.user.expenses.includes(:funding_schedule).order(:due_on, :name)
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def new
    @funding_schedules = Current.user.funding_schedules.order(:name)
    @expense = Current.user.expenses.new(
      cadence: 'monthly',
      due_on: Date.current,
      funding_schedule: @funding_schedules.first
    )
  end

  def edit
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def create
    @expense = Current.user.expenses.new(expense_params)

    if @expense.save
      load_expenses_for_index
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to expenses_path, notice: 'Expense created' }
      end
    else
      @funding_schedules = Current.user.funding_schedules.order(:name)
      render :new, status: :unprocessable_content, formats: [ :html ]
    end
  end

  def update
    unless @expense.update(expense_params)
      @funding_schedules = Current.user.funding_schedules.order(:name)
      return render :edit, status: :unprocessable_content, formats: [ :html ]
    end

    allocation = apply_allocated_amount(@expense)
    if allocation && !allocation.ok?
      @allocation_error = allocation.error
      @funding_schedules = Current.user.funding_schedules.order(:name)
      return render :edit, status: :unprocessable_content, formats: [ :html ]
    end

    load_expenses_for_index
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to expenses_path, notice: 'Expense updated' }
    end
  end

  def destroy
    @expense.destroy
    load_expenses_for_index
    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_to expenses_path, status: :see_other }
    end
  end

  private

  def set_expense
    @expense = Current.user.expenses.find(params.expect(:id))
  end

  def load_expenses_for_index
    @expenses = Current.user.expenses.includes(:funding_schedule).order(:due_on, :name)
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def expense_params
    params.expect(expense: [ :name, :amount, :cadence, :due_on, :funding_schedule_id ])
  end

  # The drawer's "Allocated" field (shown only when a bank is linked) sets the
  # bucket balance to the typed total. Blank means "leave it alone". Returns the
  # ManualAllocator result, or nil when there's nothing to apply.
  def apply_allocated_amount(expense)
    amount = params.fetch(:allocated_amount, nil)
    return if amount.blank?

    ManualAllocator.set_balance(item: expense, amount: amount.to_d)
  end
end
