# Replaces open self-registration: people ask for an account and a site
# admin approves or declines.
class CreateAccessRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :access_requests do |t|
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :email,      null: false
      t.string :position,   null: false
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :access_requests, [:status, :created_at]
    add_index :access_requests, :email
  end
end
