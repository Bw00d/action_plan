class CreateCovers < ActiveRecord::Migration[5.2]
  def change
    create_table :covers do |t|
      t.integer :plan_id

      t.timestamps
    end
  end
end
