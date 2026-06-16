class CreateFundingEventsAndAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :funding_events, id: :uuid do |t|
      t.references :funding_schedule, null: false, foreign_key: true, type: :uuid
      t.date :occurs_on, null: false
      t.datetime :processed_at

      t.timestamps

      t.index [ :funding_schedule_id, :occurs_on ], unique: true
    end

    create_table :allocations, id: :uuid do |t|
      t.references :funding_event, null: false, foreign_key: true, type: :uuid
      t.references :expense, null: false, foreign_key: true, type: :uuid
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.datetime :funded_at

      t.timestamps

      t.index [ :funding_event_id, :expense_id ], unique: true
    end
  end
end
