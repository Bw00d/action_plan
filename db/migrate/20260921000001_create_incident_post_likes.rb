class CreateIncidentPostLikes < ActiveRecord::Migration[6.0]
  def change
    create_table :incident_post_likes do |t|
      t.bigint :incident_post_id, null: false
      t.bigint :user_id,          null: false
      t.timestamps
    end
    add_index :incident_post_likes, [:incident_post_id, :user_id], unique: true, name: 'idx_incident_post_likes_unique'
    add_index :incident_post_likes, :user_id
  end
end
