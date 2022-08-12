class AddReleaseDateToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :release_date, :date
  end
end
