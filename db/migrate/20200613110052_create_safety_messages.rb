class CreateSafetyMessages < ActiveRecord::Migration[5.1]
  def change
    create_table :safety_messages do |t|
      t.text :hazards
      t.text :narrative
      t.string :prepared_by
      t.integer :plan_id

      t.timestamps
    end
  end
end
