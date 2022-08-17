class CommoPlan < ApplicationRecord
  belongs_to :plan
  has_many :commo_items, dependent: :destroy
end
