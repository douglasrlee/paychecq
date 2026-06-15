class ProcessFundingEventsJob < ApplicationJob
  queue_as :default

  def perform
    FundingSchedule.find_each do |schedule|
      schedule.materialize_events_through(end_date: Date.current)
    end

    FundingEvent.where(processed_at: nil)
                .where(occurs_on: ..Date.current)
                .find_each do |event|
      AllocationEngine.propose_for(event)
    rescue StandardError => error
      Rails.logger.error("AllocationEngine.propose_for failed for funding_event=#{event.id}: #{error.message}")
      Appsignal.send_error(error)
    end

    User.joins(:expenses).distinct.find_each do |user|
      AllocationEngine.fund_pending_for(user)
    rescue StandardError => error
      Rails.logger.error("AllocationEngine.fund_pending_for failed for user=#{user.id}: #{error.message}")
      Appsignal.send_error(error)
    end
  end
end
