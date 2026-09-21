class CreateIncidentFeedVisits < ActiveRecord::Migration[6.0]
  def change
    create_table :incident_feed_visits do |t|
      t.bigint   :user_id,      null: false
      t.bigint   :incident_id,  null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :incident_feed_visits, [:user_id, :incident_id], unique: true
    add_index :incident_feed_visits, :incident_id
  end
end
