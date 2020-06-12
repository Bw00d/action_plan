class CreateCommoItems < ActiveRecord::Migration[5.1]
  def change
    create_table :commo_items do |t|
      t.string :zone
      t.string :ch_num
      t.string :function
      t.string :channel_name
      t.string :assignment
      t.string :rx_freq
      t.string :rx_tone
      t.string :tx_freq
      t.string :tx_tone
      t.string :mode
      t.integer :commo_plan_id

      t.timestamps
    end
  end
end
