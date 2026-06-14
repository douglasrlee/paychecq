class FundingSchedulesController < ApplicationController
  before_action :set_funding_schedule, only: [ :edit, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to settings_path, alert: 'Funding schedule not found'
  end

  def new
    @funding_schedule = Current.user.funding_schedules.new(start_date: Date.current)
  end

  def edit; end

  def create
    @funding_schedule = Current.user.funding_schedules.new(funding_schedule_params)

    if @funding_schedule.save
      load_schedules_for_settings
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to settings_path, notice: 'Funding schedule created' }
      end
    else
      render :new, status: :unprocessable_content, formats: [ :html ]
    end
  end

  def update
    if @funding_schedule.update(funding_schedule_params)
      load_schedules_for_settings
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to settings_path, notice: 'Funding schedule updated' }
      end
    else
      render :edit, status: :unprocessable_content, formats: [ :html ]
    end
  end

  def destroy
    if @funding_schedule.destroy
      redirect_to settings_path, notice: 'Funding schedule deleted', status: :see_other
    else
      redirect_to settings_path, alert: @funding_schedule.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_funding_schedule
    @funding_schedule = Current.user.funding_schedules.find(params.expect(:id))
  end

  def load_schedules_for_settings
    @funding_schedules = Current.user.funding_schedules.order(:name)
  end

  def funding_schedule_params
    permitted = params.expect(funding_schedule: [ :name, :cadence, :start_date, :second_day_of_month ])
    permitted[:second_day_of_month] = nil if permitted[:cadence] != 'semimonthly'
    permitted
  end
end
