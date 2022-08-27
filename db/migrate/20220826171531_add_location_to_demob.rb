class AddLocationToDemob < ActiveRecord::Migration[5.2]
  def change
    add_column :demobs, :new_location, :string
  end
end
