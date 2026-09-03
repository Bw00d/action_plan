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
      # Freeze only the resources the board currently shows — demobed /
      # R&R resources whose OrgUnitAssignments still linger should not be
      # baked into a published plan's historical record.
      OrgUnitAssignment
        .joins(:org_unit, :resource)
        .where(org_units: { incident_id: @plan.incident_id })
        .where(resources: { release_date: nil, r_and_r: false })
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
