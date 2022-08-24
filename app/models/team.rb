class Team < ApplicationRecord
  belongs_to :plan
  has_one :resource
  after_destroy :update_204

  def update_204
    id = self.id.to_s
    self.plan.assignments.each do |a|

      if !a.ops_personnel_ids.nil? && a.ops_personnel_ids.include?(id)
        a.update_resources(id)
      end
    end
  end
end
