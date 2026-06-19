class AddPreviousDueOnToTransactions < ActiveRecord::Migration[8.1]
  # Remembers the expense's due_on at the moment we linked this transaction,
  # so unlink can restore the expense to that exact date. Otherwise the
  # bump_forward / bump_backward round-trip loses the day when forward
  # clamps (Jan 31 -> Feb 28 -> backward yields Jan 28, not Jan 31).
  def change
    add_column :transactions, :previous_due_on, :date
  end
end
