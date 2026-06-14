class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :funding_schedule, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :cadence, null: false
      t.date :due_on, null: false

      t.timestamps
    end
  end
end
