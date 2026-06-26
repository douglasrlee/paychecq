class AllowManualAllocations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # A manual allocation is an Allocation with no funding_event — the user put
  # money into a bucket directly rather than a paycheck proposing it. Drop the
  # NOT NULL so those rows can exist, and add partial unique indexes so a bucket
  # can only have one manual row (the running net manual contribution). The
  # existing [funding_event_id, expense_id]/[..goal_id] unique indexes only
  # cover auto rows, which always carry a funding_event_id.
  def change
    change_column_null :allocations, :funding_event_id, true

    add_index :allocations, :expense_id,
              unique: true,
              where: 'funding_event_id IS NULL AND expense_id IS NOT NULL',
              name: 'index_allocations_on_manual_expense_id',
              algorithm: :concurrently

    add_index :allocations, :goal_id,
              unique: true,
              where: 'funding_event_id IS NULL AND goal_id IS NOT NULL',
              name: 'index_allocations_on_manual_goal_id',
              algorithm: :concurrently
  end
end
