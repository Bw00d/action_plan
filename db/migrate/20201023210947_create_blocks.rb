class CreateBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :blocks do |t|
      t.string :font_size, default: 'h2'
      t.string :font_family, 'Arial'
      t.string :content
      t.string :number
      t.integer :cover_id
      t.string :font_weight, default: 'semi-bold'
      t.string :text_align, default: 'center'
      t.string :text_style, default: 'normal'

      t.timestamps
    end
  end
end
