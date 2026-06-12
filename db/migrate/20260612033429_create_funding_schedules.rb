class CreateFundingSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :funding_schedules, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :cadence, null: false
      t.date :start_date, null: false
      t.integer :second_day_of_month

      t.timestamps
    end
  end
end
