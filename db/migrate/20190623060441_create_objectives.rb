class CreateObjectives < ActiveRecord::Migration[5.1]
  def change
    create_table :objectives do |t|
      t.integer :plan_id
      t.string :description
      t.integer :order

      t.timestamps
    end
  end
end
