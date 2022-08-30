json.extract! attachment, :id, :description, :attached, :plan_id, :created_at, :updated_at
json.url attachment_url(attachment, format: :json)
