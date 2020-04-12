class CreateActivities < ActiveRecord::Migration[5.1]
  def change
    create_table :activities do |t|
      t.integer :plan_id
      t.string :description
      t.boolean :completed

      t.timestamps
    end
  end
end
