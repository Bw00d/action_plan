json.extract! incident, :id, :name, :number, :created_at, :updated_at
json.url incident_url(incident, format: :json)
