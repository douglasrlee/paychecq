class ValidateGoalsForeignKeysAndConstraints < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :goals, :users
    validate_foreign_key :goals, :funding_schedules
    validate_foreign_key :allocations, :goals
    validate_foreign_key :transactions, :goals
    validate_check_constraint :allocations, name: 'allocations_exactly_one_allocatable'
  end
end
