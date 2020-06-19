class CreateTeams < ActiveRecord::Migration[5.1]
  def change
    create_table :teams do |t|
      t.string :resource_name
      t.string :position
      t.string :staff
      t.integer :plan_id

      t.timestamps
    end
  end
end
