class CreateAttachments < ActiveRecord::Migration[5.2]
  def change
    create_table :attachments do |t|
      t.string :description
      t.boolean :attached
      t.integer :plan_id

      t.timestamps
    end
  end
end
