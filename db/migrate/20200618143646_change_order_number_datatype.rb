class ChangeOrderNumberDatatype < ActiveRecord::Migration[5.1]
  def change
    remove_column :resources, :order_number, :string
    add_column :resources, :order_number, :integer
  end
end
