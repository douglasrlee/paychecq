class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    enable_extension "citext"

    create_table :users, id: :uuid do |table|
      table.string :first_name, null: false
      table.string :last_name, null: false
      table.citext :email, null: false
      table.string :password_digest, null: false

      table.timestamps
    end

    add_index :users, :email, unique: true
  end
end
