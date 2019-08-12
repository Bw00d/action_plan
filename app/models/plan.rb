class Plan < ApplicationRecord
  belongs_to :user
  belongs_to :incident
  has_many :objectives, dependent: :destroy
  validates :user_id, presence: true
  validates :date, presence: true, uniqueness: true

end
