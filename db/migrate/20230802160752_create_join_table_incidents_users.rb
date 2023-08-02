class CreateJoinTableIncidentsUsers < ActiveRecord::Migration[5.2]
  def change
    create_join_table :incidents, :users do |t|
      t.index [:incident_id, :user_id]
      t.index [:user_id, :incident_id]
    end
  end
end
