class AddRosterToDemobs < ActiveRecord::Migration[6.0]
  def change
    add_reference :demobs, :roster, null: true, foreign_key: true
  end
end
