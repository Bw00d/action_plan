class AddRonLocationToDemobs < ActiveRecord::Migration[6.0]
  def change
    add_column :demobs, :ron_location, :string
  end
end
