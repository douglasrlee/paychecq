class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pg_trgm'

    create_table :transactions, id: :uuid do |table|
      table.string :name, null: false
      table.decimal :amount, precision: 10, scale: 2, null: false
      table.boolean :pending, null: false, default: false

      table.timestamps
    end

    add_index :transactions, :name, using: :gin, opclass: :gin_trgm_ops
  end
end
