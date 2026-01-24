require 'test_helper'

class ClearSolidQueueJobsJobTest < ActiveJob::TestCase
  test 'clears finished jobs with appsignal checkin' do
    clear_args = nil
    checkin_identifier = nil

    SolidQueue::Job.define_singleton_method(:clear_finished_in_batches) do |**args|
      clear_args = args
    end

    Appsignal::CheckIn.define_singleton_method(:cron) do |identifier, &block|
      checkin_identifier = identifier
      block.call
    end

    ClearSolidQueueJobsJob.perform_now

    assert_equal({ sleep_between_batches: 0.3 }, clear_args)
    assert_equal 'clear_solid_queue_finished_jobs', checkin_identifier
  end
end
