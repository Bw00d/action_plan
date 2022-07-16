class CreatePosts < ActiveRecord::Migration[5.2]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.datetime :posted_at
      t.integer :user_id
      t.integer :incident_id

      t.timestamps
    end
  end
end
