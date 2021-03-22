class CreateBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :blocks do |t|
      t.string :font_size
      t.string :font_family
      t.string :content
      t.string :number
      t.integer :cover_id

      t.timestamps
    end
  end
end
