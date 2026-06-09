class CreateTransactionNameOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_name_overrides, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :match_type, null: false
      t.citext :match_text, null: false
      t.string :replacement_name, null: false

      t.timestamps

      t.index [ :user_id, :match_type, :match_text ], unique: true, name: 'index_transaction_name_overrides_uniqueness'
    end
  end
end
