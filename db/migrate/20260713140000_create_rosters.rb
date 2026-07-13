class CreateRosters < ActiveRecord::Migration[6.0]
  def change
    create_table :rosters do |t|
      t.references :resource, null: false, foreign_key: true, index: true
      t.references :request,  null: true,  foreign_key: true, index: true
      t.string  :name
      t.string  :position
      t.string  :order_number
      t.integer :position_num
      t.text    :notes
      t.timestamps
    end
  end
end
