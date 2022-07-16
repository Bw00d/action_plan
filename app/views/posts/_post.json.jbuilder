json.extract! post, :id, :title, :body, :posted_at, :user_id, :created_at, :updated_at
json.url post_url(post, format: :json)
