class CreateIncidentEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :incident_events do |t|
      t.references :incident, null: false, foreign_key: true
      # Nullable — background jobs or system-triggered events won't have
      # a user. Use SET NULL rather than CASCADE so removing a user
      # doesn't wipe their historical audit trail.
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.string :message, null: false
      t.jsonb :details, default: {}, null: false
      t.datetime :created_at, null: false
    end

    add_index :incident_events, [:incident_id, :created_at]
    add_index :incident_events, :kind
  end
end
