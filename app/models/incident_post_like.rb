class IncidentPostLike < ApplicationRecord
  belongs_to :incident_post
  belongs_to :user

  validates :user_id, uniqueness: { scope: :incident_post_id }
end
