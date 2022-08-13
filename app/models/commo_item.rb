class CommoItem < ApplicationRecord
  belongs_to :commo_plan, dependent: :destroy
end
