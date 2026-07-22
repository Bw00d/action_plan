class Cover < ApplicationRecord
  # Canvas-model rewrite: blocks are positioned free-form on the cover.
  # Order the collection by created_at so newer blocks sit on top when
  # z-index ties are needed.
  has_many :blocks, -> { order(created_at: :asc) }, dependent: :destroy
  belongs_to :plan

  def plan
    Plan.find(self.plan_id)
  end
end
