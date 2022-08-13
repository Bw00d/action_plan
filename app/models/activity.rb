class Activity < ApplicationRecord
  belongs_to :plan, dependent: :destroy
end
