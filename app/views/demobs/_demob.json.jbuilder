json.extract! demob, :id, :resource_id, :remarks, :edd, :edt, :destination, :travel_method, :manifest, :manifest_number, :ron, :actual_release_date, :actual_release_time, :eta, :contact_enroute, :agency_notified, :reassigned, :new_incident, :new_incident_number, :new_order_number, :prepared_by, :pb_position, :date, :time, :created_at, :updated_at
json.url demob_url(demob, format: :json)
