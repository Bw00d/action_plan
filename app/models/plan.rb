class Plan < ApplicationRecord
  belongs_to :user
  belongs_to :plan
  has_many :objectives
  validates :user_id, presence: true
  validates :date, presence: true, uniqueness: true

end
