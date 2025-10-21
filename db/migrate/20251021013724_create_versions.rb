# This migration creates the `versions` table, the only schema PaperTrail requires.
# All other migrations PaperTrail provides are optional.
class CreateVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :versions, id: :uuid do |table|
      # Consider using a bigint type for performance if you are going to store only numeric ids.
      # table.bigint :whodunnit
      table.string   :whodunnit

      # Known issue in MySQL: fractional second precision
      # -------------------------------------------------
      #
      # MySQL timestamp columns do not support fractional seconds unless
      # defined with "fractional seconds precision". MySQL users should manually
      # add fractional seconds precision to this migration, specifically, to
      # the `created_at` column.
      # (https://dev.mysql.com/doc/refman/5.6/en/fractional-seconds.html)
      #
      # MySQL users should also upgrade to at least rails 4.2, which is the first
      # version of ActiveRecord with support for fractional seconds in MySQL.
      # (https://github.com/rails/rails/pull/14359)
      #
      # MySQL users should use the following line for `created_at`
      # table.datetime :created_at, limit: 6
      table.datetime :created_at

      table.string   :item_id,   null: false
      table.string   :item_type, null: false
      table.string   :event,     null: false
      table.jsonb    :object
    end

    add_index :versions, %i[item_type item_id]
  end
end
