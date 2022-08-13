class Objective < ApplicationRecord
  belongs_to :plan

  before_create :set_order

  def set_order
      
      objectives = self.plan.objectives
      if !objectives.empty?
        self.order = objectives.last.order + 1
      else
        self.order = 1
      end
    end
end
