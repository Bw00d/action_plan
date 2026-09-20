class CreateIsuiteImportStagings < ActiveRecord::Migration[6.0]
  def change
    create_table :isuite_import_stagings do |t|
      t.string   :token,       null: false
      t.bigint   :incident_id, null: false
      t.bigint   :user_id
      t.text     :csv_data,    null: false
      t.datetime :expires_at,  null: false
      t.timestamps
    end
    add_index :isuite_import_stagings, :token, unique: true
    add_index :isuite_import_stagings, :expires_at
  end
end
