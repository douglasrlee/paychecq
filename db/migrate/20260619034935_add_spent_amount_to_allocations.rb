class AddSpentAmountToAllocations < ActiveRecord::Migration[8.1]
  def up
    add_column :allocations, :spent_amount, :decimal, precision: 10, scale: 2, default: 0, null: false

    # Existing fully-spent rows must have spent_amount = amount so the new
    # bucket_balance (which reads `sum(amount - spent_amount)`) excludes
    # them, matching today's "spent_at IS NOT NULL" filter behavior.
    safety_assured do
      execute <<~SQL.squish
        UPDATE allocations
        SET spent_amount = amount
        WHERE spent_at IS NOT NULL
      SQL
    end
  end

  def down
    remove_column :allocations, :spent_amount
  end
end
