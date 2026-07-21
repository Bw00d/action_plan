class Team < ApplicationRecord
  belongs_to :plan
  has_one :resource
  after_destroy :update_204

  acts_as_list scope: [:plan_id, :staff], column: :list_position

  # A Team row with header_label set renders as a section separator
  # (e.g. "Branch I" inside Operations) rather than a name+position row.
  # Use this scope wherever we need only the person/position rows (e.g. the
  # 204 personnel picker) so headers don't show up as selectable.
  scope :not_headers, -> { where(header_label: [nil, ""]) }

  def header?
    header_label.present?
  end

  def update_204
    id = self.id.to_s
    self.plan.assignments.each do |a|

      if !a.ops_personnel_ids.nil? && a.ops_personnel_ids.include?(id)
        a.update_resources(id)
      end
    end
  end
end
