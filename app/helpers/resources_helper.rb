module ResourcesHelper
  # Overhead-style tally: { "AGENCY" => count }.
  def tally_resources(resources)
    totals = Hash.new(0)
    resources.each do |r|
      r.personnel_by_agency.each { |agency, count| totals[agency] += count }
    end
    totals
  end

  def get_agencies(resources)
    resources.map { |r| r.agency }
  end

  def get_resources(resources)
    resources
  end

  def release_resource(resource)
    resource.update_attribute(release_date: resource.demob.actual_release_date)
  end

  # Crew/Equipment-style tally: [resource_count, agency, position, personnel_total]
  # per unique (agency, position). Resources whose subordinates come from
  # multiple agencies contribute one row per agency they cover.
  def tally_assigned_resources(resources)
    buckets = Hash.new { |h, k| h[k] = { resource_ids: Set.new, personnel: 0 } }
    resources.each do |r|
      r.personnel_by_agency.each do |agency, count|
        key = [agency, r.position]
        buckets[key][:resource_ids] << r.id
        buckets[key][:personnel]    += count
      end
    end
    buckets.map do |(agency, position), bucket|
      [bucket[:resource_ids].size, agency, position, bucket[:personnel]]
    end
  end
end
