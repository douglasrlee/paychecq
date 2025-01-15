# frozen_string_literal: true

class CreateSolidQueueJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :active_job_id, name: 'index_solid_queue_jobs_on_active_job_id'
      t.index :class_name, name: 'index_solid_queue_jobs_on_class_name'
      t.index :finished_at, name: 'index_solid_queue_jobs_on_finished_at'
      t.index [ :queue_name, :finished_at ], name: 'index_solid_queue_jobs_for_filtering'
      t.index [ :scheduled_at, :finished_at ], name: 'index_solid_queue_jobs_for_alerting'
    end
  end
end
