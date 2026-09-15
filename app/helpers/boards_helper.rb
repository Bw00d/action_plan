module BoardsHelper
  def column_subtitle(unit)
    ancestors = []
    current = unit.parent
    while current
      ancestors.unshift(current.name)
      current = current.parent
    end
    ancestors.join(' / ').presence
  end

  # The most recent 204 (Assignment) for this org unit across all plans on
  # the incident. Prefer a draft plan (that's what the user is usually
  # editing), fall back to the latest published plan. Returns nil if no
  # 204 has been created for this unit yet.
  def latest_assignment_for(unit)
    return nil unless unit&.persisted?

    scope = Assignment.where(org_unit_id: unit.id)
                      .joins(:plan)
                      .where(plans: { incident_id: unit.incident_id })

    draft = scope.where(plans: { published_at: nil })
                 .order('plans.created_at DESC').first
    return draft if draft

    scope.order('plans.published_at DESC NULLS LAST, plans.created_at DESC').first
  end

  # Short human label for the 204 link — e.g. "9/15 DAY" or "Draft".
  def assignment_link_label(assignment)
    plan = assignment.plan
    date = plan.date || plan.ops_period_from&.to_date || plan.created_at&.to_date
    shift = plan.shift.presence
    [date&.strftime('%-m/%-d'), shift].compact.join(' ').presence || 'Plan'
  end
end
