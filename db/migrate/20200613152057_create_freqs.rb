class CreateFreqs < ActiveRecord::Migration[5.1]
  def change
    create_table :freqs do |t|
      t.integer :assignment_id
      t.integer :commo_item_id

      t.timestamps
    end
  end
end
