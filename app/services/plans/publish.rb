module Plans
  class Publish
    def self.call(plan)
      new(plan).call
    end

    def initialize(plan)
      @plan = plan
    end

    def call
      ActiveRecord::Base.transaction do
        PlanAssignmentSnapshot.where(plan_id: @plan.id).delete_all
        snapshot_current_assignments
        @plan.update!(published_at: Time.current)
      end
      @plan
    end

    private

    def snapshot_current_assignments
      OrgUnitAssignment
        .joins(:org_unit)
        .where(org_units: { incident_id: @plan.incident_id })
        .includes(:org_unit)
        .find_each do |assignment|
        PlanAssignmentSnapshot.create!(
          plan: @plan,
          org_unit: assignment.org_unit,
          resource_id: assignment.resource_id,
          position: assignment.position,
          designator_at_publish: assignment.org_unit.designator
        )
      end
    end
  end
end
