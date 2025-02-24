# frozen_string_literal: true

class CreateSolidQueueReadyExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_ready_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false

      t.index :job_id, name: 'index_solid_queue_ready_executions_on_job_id', unique: true
      t.index [ :priority, :job_id ], name: 'index_solid_queue_poll_all'
      t.index [ :queue_name, :priority, :job_id ], name: 'index_solid_queue_poll_by_queue'
    end
  end
end
