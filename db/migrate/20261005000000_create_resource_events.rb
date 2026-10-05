class CreateResourceEvents < ActiveRecord::Migration[6.0]
  # Activity feed for a Resource — unified comment + crew-swap log that
  # powers the right-hand "Comments and activity" panel on the expanded
  # T-card modal. Backfills existing Resource#comment strings as
  # comment events so historical notes survive the migration.
  def up
    create_table :resource_events do |t|
      t.references :resource, null: false, foreign_key: true, index: true
      t.references :user,     null: true,  foreign_key: true

      # 0=comment, 1=scheduled_swap, 2=completed_swap. Enum lives on
      # the model.
      t.integer :kind, null: false, default: 0

      t.text    :body
      t.string  :leader
      t.date    :fwd
      t.date    :lwd
      t.string  :phone

      t.timestamps
    end

    add_index :resource_events, [:resource_id, :created_at]
    add_index :resource_events, [:resource_id, :kind]

    # Backfill: migrate any existing Resource.comment string into a
    # kind=comment event so historical notes aren't lost. Leaves the
    # column itself in place for safety — we'll stop writing to it in
    # the model and can retire it in a follow-up.
    now = Time.current
    rows = []
    execute("SELECT id, comment FROM resources WHERE comment IS NOT NULL AND comment <> ''").each do |row|
      rows << "(#{row['id']}, 0, #{connection.quote(row['comment'])}, '#{now.iso8601}', '#{now.iso8601}')"
    end
    if rows.any?
      execute <<~SQL
        INSERT INTO resource_events (resource_id, kind, body, created_at, updated_at)
        VALUES #{rows.join(',')}
      SQL
    end
  end

  def down
    drop_table :resource_events
  end
end
