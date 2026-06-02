module Plans
  class Unpublish
    def self.call(plan)
      new(plan).call
    end

    def initialize(plan)
      @plan = plan
    end

    def call
      ActiveRecord::Base.transaction do
        PlanAssignmentSnapshot.where(plan_id: @plan.id).delete_all
        @plan.update!(published_at: nil)
      end
      @plan
    end
  end
end
