class Team < ApplicationRecord
  belongs_to :plan
  has_one :resource
end
