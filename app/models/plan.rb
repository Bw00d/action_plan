class Plan < ApplicationRecord
  belongs_to :user
  has_many :objectives
  validates :user_id, presence: true
  validates :date, presence: true, uniqueness: true

end
