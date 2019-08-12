class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy
end
