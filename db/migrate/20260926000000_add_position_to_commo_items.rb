class AddPositionToCommoItems < ActiveRecord::Migration[6.0]
  def up
    add_column :commo_items, :position, :integer unless column_exists?(:commo_items, :position)

    # Backfill: number existing items within each plan by (created_at, id)
    # order so display stays in insertion order after the switch.
    execute <<~SQL
      WITH numbered AS (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY commo_plan_id ORDER BY created_at, id) AS rn
        FROM commo_items
      )
      UPDATE commo_items
         SET position = numbered.rn
        FROM numbered
       WHERE commo_items.id = numbered.id
         AND commo_items.position IS NULL;
    SQL

    add_index :commo_items, [:commo_plan_id, :position]
  end

  def down
    remove_index :commo_items, [:commo_plan_id, :position] if index_exists?(:commo_items, [:commo_plan_id, :position])
    remove_column :commo_items, :position if column_exists?(:commo_items, :position)
  end
end
