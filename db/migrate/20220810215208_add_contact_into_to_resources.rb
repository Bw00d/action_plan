class AddContactIntoToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :assignment_length, :integer
    add_column :resources, :phone, :string
    add_column :resources, :email, :string
    add_column :resources, :comment, :text
    add_column :resources, :fwd, :date
    remove_column :resources, :lwd, :date
  end
end
