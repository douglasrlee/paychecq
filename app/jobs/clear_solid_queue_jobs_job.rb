class ClearSolidQueueJobsJob < ApplicationJob
  def perform
    Appsignal::CheckIn.cron('clear_solid_queue_finished_jobs') do
      SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
    end
  end
end
