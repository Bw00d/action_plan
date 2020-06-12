class CreateCommoPlans < ActiveRecord::Migration[5.1]
  def change
    create_table :commo_plans do |t|
      t.integer :plan_id
      t.string :date_prepared
      t.string :ops_period
      t.text :special_instructions
      t.string :prepared_by
      t.string :date_signed


      t.timestamps
    end
  end
end
