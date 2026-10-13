class AddUserToSchedules < ActiveRecord::Migration[6.0]
  def change
    # Nullable because the existing meeting-schedule rows aren't owned
    # by any user (incident-wide shared schedule). Per-user "My Schedule"
    # rows set user_id to the owning user.
    add_reference :schedules, :user, foreign_key: true, null: true

    # Pair with incident_id so the (meeting_schedule vs my_schedule)
    # lookup in the controller stays indexed.
    add_index :schedules, [:incident_id, :user_id]
  end
end
