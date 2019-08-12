class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
end
