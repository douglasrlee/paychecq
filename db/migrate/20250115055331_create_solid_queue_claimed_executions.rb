# frozen_string_literal: true

class CreateSolidQueueClaimedExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_claimed_executions do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index :job_id, name: 'index_solid_queue_claimed_executions_on_job_id', unique: true
      t.index [ :process_id, :job_id ], name: 'index_solid_queue_claimed_executions_on_process_id_and_job_id'
    end
  end
end
