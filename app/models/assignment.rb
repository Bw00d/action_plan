class Assignment < ApplicationRecord
  belongs_to :plan
  has_many :commo_items, through: :freqs
  has_many :freqs
end
