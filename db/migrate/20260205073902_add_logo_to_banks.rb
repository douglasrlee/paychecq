class AddLogoToBanks < ActiveRecord::Migration[8.1]
  def change
    add_column :banks, :logo, :text
  end
end
