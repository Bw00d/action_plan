# Fields the remote check-in form captures that Resource didn't
# previously have a home for. The RequestCheckinsController overlay
# now copies these from a promoted RemoteCheckin into the resource,
# and the manual check-in form exposes them so dispatchers can enter
# the same info for walk-ups.
class AddCheckinAttributesToResources < ActiveRecord::Migration[6.0]
  def change
    change_table :resources do |t|
      t.string  :agency_address
      t.string  :emergency_contact
      t.date    :mobilization_date
      t.string  :transportation_method
      # When the resource came off another incident immediately before
      # this one — matters for 2:1 and 14-day rules.
      t.boolean :from_other_incident,           default: false, null: false
      t.string  :other_incident_name
      t.string  :other_incident_req_number
      # First day they worked on that previous incident. (The remote
      # form captures first day; the planner can convert / cross-check
      # against the resource's travel + rest math.)
      t.date    :prev_incident_first_day_worked
    end
  end
end
