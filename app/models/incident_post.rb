class IncidentPost < ApplicationRecord
  belongs_to :incident
  belongs_to :user
  belongs_to :parent, class_name: 'IncidentPost', optional: true
  has_many   :replies, -> { order(:created_at) },
             class_name: 'IncidentPost', foreign_key: :parent_id, dependent: :destroy
  has_many   :likes, class_name: 'IncidentPostLike', dependent: :destroy
  has_many   :liking_users, through: :likes, source: :user

  validates :body, presence: true, length: { maximum: 5000 }

  scope :top_level, -> { where(parent_id: nil) }

  def author_name
    name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
    name.presence || user.email
  end

  def liked_by?(some_user)
    return false unless some_user
    likes.exists?(user_id: some_user.id)
  end
end
