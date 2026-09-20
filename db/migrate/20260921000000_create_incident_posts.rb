class CreateIncidentPosts < ActiveRecord::Migration[6.0]
  def change
    create_table :incident_posts do |t|
      t.bigint :incident_id, null: false
      t.bigint :user_id,     null: false
      t.bigint :parent_id                 # nullable — top-level post if nil
      t.text   :body,        null: false
      t.timestamps
    end
    add_index :incident_posts, [:incident_id, :created_at]
    add_index :incident_posts, :parent_id
    add_index :incident_posts, :user_id
  end
end
