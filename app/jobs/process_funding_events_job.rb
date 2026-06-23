class ProcessFundingEventsJob < ApplicationJob
  queue_as :default

  def perform
    FundingSchedule.find_each do |schedule|
      schedule.materialize_events_through(end_date: Date.current)
    end

    # Iterate via .each with explicit chronological order — propose_for
    # builds on the expense's existing allocations, so events must be
    # processed oldest-first. find_each batches by primary key (UUID) and
    # would silently shuffle the order.
    FundingEvent.where(processed_at: nil)
                .where(occurs_on: ..Date.current)
                .order(:occurs_on, :created_at)
                .each do |event|
      AllocationEngine.propose_for(event)
    rescue StandardError => error
      Rails.logger.error("AllocationEngine.propose_for failed for funding_event=#{event.id}: #{error.message}")
      Appsignal.send_error(error)
    end

    # Only walk users who actually have pending allocations to fund. Avoids
    # acquiring a row lock per user every hour when nothing changed.
    ids_via_expenses = User.joins(expenses: :allocations)
                           .where(allocations: { funded_at: nil })
                           .distinct.pluck(:id)
    ids_via_goals = User.joins(goals: :allocations)
                        .where(allocations: { funded_at: nil })
                        .distinct.pluck(:id)
    User.where(id: ids_via_expenses | ids_via_goals).find_each do |user|
      AllocationEngine.fund_pending_for(user)
    rescue StandardError => error
      Rails.logger.error("AllocationEngine.fund_pending_for failed for user=#{user.id}: #{error.message}")
      Appsignal.send_error(error)
    end
  end
end
