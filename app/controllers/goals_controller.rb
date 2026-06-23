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
    if @goal.update(goal_params)
      load_goals_for_index
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to goals_path, notice: 'Goal updated' }
      end
    else
      @funding_schedules = Current.user.funding_schedules.order(:name)
      render :edit, status: :unprocessable_content, formats: [ :html ]
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
end
