# frozen_string_literal: true

class CreateSolidQueueProcesses < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
      t.string :name, null: false

      t.index :last_heartbeat_at, name: 'index_solid_queue_processes_on_last_heartbeat_at'
      t.index [ :name, :supervisor_id ], name: 'index_solid_queue_processes_on_name_and_supervisor_id', unique: true
      t.index :supervisor_id, name: 'index_solid_queue_processes_on_supervisor_id'
    end
  end
end
