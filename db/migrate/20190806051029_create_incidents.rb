class CreateIncidents < ActiveRecord::Migration[5.1]
  def change
    create_table :incidents do |t|
      t.string  :name
      t.string  :p_code
      t.string  :number
      t.integer :user_id

      t.timestamps
    end
  end
end
