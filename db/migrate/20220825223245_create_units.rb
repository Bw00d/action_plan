class CreateUnits < ActiveRecord::Migration[5.2]
  def change
    create_table :units do |t|
      t.boolean :selected
      t.string :manager
      t.string :remarks
      t.string :name
      t.integer :demob_id
      t.integer :order

      t.timestamps
    end
  end
end
