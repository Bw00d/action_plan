class CommoPlan < ApplicationRecord
  belongs_to :plan, dependent: :destroy
  has_many :commo_items
end
