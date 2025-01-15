# frozen_string_literal: true

class CreateSolidQueueFailedExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_failed_executions do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false

      t.index :job_id, name: 'index_solid_queue_failed_executions_on_job_id', unique: true
    end
  end
end
