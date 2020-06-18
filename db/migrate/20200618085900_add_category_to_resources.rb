class AddCategoryToResources < ActiveRecord::Migration[5.1]
  def change
    add_column :resources, :category, :string
  end
end
