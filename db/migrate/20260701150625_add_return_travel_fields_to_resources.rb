class AddReturnTravelFieldsToResources < ActiveRecord::Migration[6.0]
  def change
    add_column :resources, :jetport,      :string unless column_exists?(:resources, :jetport)
    add_column :resources, :return_city,  :string unless column_exists?(:resources, :return_city)
    add_column :resources, :return_state, :string unless column_exists?(:resources, :return_state)
  end
end
