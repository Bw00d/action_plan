class AddSituationToPlan < ActiveRecord::Migration[5.1]
  def change
    add_column :plans, :situation, :text
  end
end
