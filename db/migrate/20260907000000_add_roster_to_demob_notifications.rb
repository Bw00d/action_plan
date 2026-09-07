class AddRosterToDemobNotifications < ActiveRecord::Migration[6.0]
  def change
    add_reference :demob_notifications, :roster, null: true, foreign_key: true
  end
end
