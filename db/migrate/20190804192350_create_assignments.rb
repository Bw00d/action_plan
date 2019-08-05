class CreateAssignments < ActiveRecord::Migration[5.1]
  def change
    create_table :assignments do |t|
      t.string :designator
      t.text :control_operations
      t.text :special_instructions
      t.integer :plan_id

      t.timestamps
    end
  end
end
