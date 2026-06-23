class CreateGoalsAndExtendAllocationsForGoals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # rubocop:disable Rails/BulkChangeTable -- bulk: true is incompatible with algorithm: :concurrently
  def change
    create_table :goals, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :cadence, null: false
      t.date :due_on, null: false
      t.uuid :funding_schedule_id, null: false
      t.uuid :user_id, null: false
      t.timestamps
    end
    add_index :goals, :user_id
    add_index :goals, :funding_schedule_id
    add_foreign_key :goals, :users, validate: false
    add_foreign_key :goals, :funding_schedules, validate: false

    # Allow an allocation to belong to a goal instead of an expense
    change_column_null :allocations, :expense_id, true

    add_column :allocations, :goal_id, :uuid
    add_index :allocations, :goal_id, algorithm: :concurrently

    add_foreign_key :allocations, :goals, validate: false

    # Replace the blanket unique index with two partial ones (one per type)
    safety_assured do
      remove_index :allocations, column: [ :funding_event_id, :expense_id ],
                                 name: 'index_allocations_on_funding_event_id_and_expense_id'
    end
    add_index :allocations, [ :funding_event_id, :expense_id ],
              unique: true,
              where: 'expense_id IS NOT NULL',
              name: 'index_allocations_on_funding_event_id_and_expense_id',
              algorithm: :concurrently
    add_index :allocations, [ :funding_event_id, :goal_id ],
              unique: true,
              where: 'goal_id IS NOT NULL',
              name: 'index_allocations_on_funding_event_id_and_goal_id',
              algorithm: :concurrently

    # Exactly one of expense_id or goal_id must be set
    add_check_constraint :allocations,
                         'num_nonnulls(expense_id, goal_id) = 1',
                         name: 'allocations_exactly_one_allocatable',
                         validate: false

    add_column :transactions, :goal_id, :uuid
    add_index :transactions, :goal_id, algorithm: :concurrently
    # on_delete: :nullify so deleting a goal clears the link instead of raising
    # an FK violation (mirrors the transactions/expenses fix in
    # CascadeNullifyTransactionExpenseLinkingFks)
    add_foreign_key :transactions, :goals, on_delete: :nullify, validate: false
  end
  # rubocop:enable Rails/BulkChangeTable
end
