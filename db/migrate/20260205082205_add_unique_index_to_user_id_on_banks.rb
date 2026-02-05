class AddUniqueIndexToUserIdOnBanks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :banks, :user_id
    add_index :banks, :user_id, unique: true, algorithm: :concurrently
  end
end
