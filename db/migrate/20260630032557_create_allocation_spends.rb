class CreateAllocationSpends < ActiveRecord::Migration[8.1]
  # Records how much of an allocation a single transaction consumed. Lets one
  # expense/goal bucket be drawn down by several transactions (e.g. an expense
  # paid by multiple charges) while keeping per-transaction rollback exact.
  # allocations.spent_amount stays as the maintained sum of these rows.
  def change
    create_table :allocation_spends, id: :uuid do |t|
      t.references :allocation, null: false, type: :uuid, foreign_key: true
      t.references :spent_by_transaction, null: false, type: :uuid, foreign_key: { to_table: :transactions }
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
