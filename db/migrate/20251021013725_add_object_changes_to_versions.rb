# This migration adds the optional `object_changes` column, in which PaperTrail
# will store the `changes` diff for each update eventable. See the readme for
# details.
class AddObjectChangesToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :object_changes, :jsonb
  end
end
