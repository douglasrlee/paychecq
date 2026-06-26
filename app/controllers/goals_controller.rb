class GoalsController < ApplicationController
  before_action :set_goal, only: [ :edit, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to goals_path, alert: 'Goal not found'
  end

  def index
    @goals = Current.user.goals.includes(:funding_schedule).order(:due_on, :name)
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def new
    @funding_schedules = Current.user.funding_schedules.order(:name)
    @goal = Current.user.goals.new(
      cadence: 'monthly',
      due_on: Date.current,
      funding_schedule: @funding_schedules.first
    )
  end

  def edit
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def create
    @goal = Current.user.goals.new(goal_params)

    if @goal.save
      load_goals_for_index
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to goals_path, notice: 'Goal created' }
      end
    else
      @funding_schedules = Current.user.funding_schedules.order(:name)
      render :new, status: :unprocessable_content, formats: [ :html ]
    end
  end

  def update
    # The drawer's Update saves the goal and its allocated balance together, so
    # apply both atomically — an allocation failure (e.g. over Free-to-Spend)
    # rolls back the record changes too.
    allocation = nil
    updated = false
    ActiveRecord::Base.transaction do
      updated = @goal.update(goal_params)
      raise ActiveRecord::Rollback unless updated

      allocation = apply_allocated_amount(@goal)
      raise ActiveRecord::Rollback if allocation && !allocation.ok?
    end

    if !updated || allocation&.error
      @allocation_error = allocation&.error
      @funding_schedules = Current.user.funding_schedules.order(:name)
      return render :edit, status: :unprocessable_content, formats: [ :html ]
    end

    load_goals_for_index
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to goals_path, notice: 'Goal updated' }
    end
  end

  def destroy
    @goal.destroy
    load_goals_for_index
    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_to goals_path, status: :see_other }
    end
  end

  private

  def set_goal
    @goal = Current.user.goals.find(params.expect(:id))
  end

  def load_goals_for_index
    @goals = Current.user.goals.includes(:funding_schedule).order(:due_on, :name)
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def goal_params
    params.expect(goal: [ :name, :amount, :cadence, :due_on, :funding_schedule_id ])
  end

  # The drawer's "Allocated" field (shown only when a bank is linked) sets the
  # bucket balance to the typed total. Blank means "leave it alone". Returns the
  # ManualAllocator result, or nil when there's nothing to apply.
  def apply_allocated_amount(goal)
    amount = params.fetch(:allocated_amount, nil)
    return if amount.blank?

    ManualAllocator.set_balance(item: goal, amount: amount.to_d)
  end
end
