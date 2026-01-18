class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'citext'

    create_table :users, id: :uuid do |table|
      table.string :first_name, null: false
      table.string :last_name, null: false
      table.citext :email_address, null: false
      table.string :password_digest, null: false

      table.timestamps
    end

    add_index :users, :email_address, unique: true
  end
end
