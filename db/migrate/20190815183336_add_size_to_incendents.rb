class AddSizeToIncendents < ActiveRecord::Migration[5.1]
  def change
    add_column :incidents, :size, :integer
    add_column :incidents, :financial_code, :string

    create_table :plan_resources do |t|
      t.integer :plan_id
      t.integer :resource_id
    end
    create_table :plan_objectives do |t|
      t.integer :plan_id
      t.integer :objective_id
    end
  end
end
