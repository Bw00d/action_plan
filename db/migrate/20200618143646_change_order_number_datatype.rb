class ChangeOrderNumberDatatype < ActiveRecord::Migration[5.1]
  def up
    change_column :resources, :order_number, 'integer USING CAST(order_number AS integer)'
  end

  def down
    change_column :resources, :order_number, :string
  end
end
