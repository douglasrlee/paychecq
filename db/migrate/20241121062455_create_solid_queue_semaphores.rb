# frozen_string_literal: true

class CreateSolidQueueSemaphores < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :expires_at, name: 'index_solid_queue_semaphores_on_expires_at'
      t.index [ :key, :value ], name: 'index_solid_queue_semaphores_on_key_and_value'
      t.index :key, name: 'index_solid_queue_semaphores_on_key', unique: true
    end
  end
end
