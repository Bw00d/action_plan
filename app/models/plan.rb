class Plan < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true
  validates :date, presence: true, uniqueness: true

end
