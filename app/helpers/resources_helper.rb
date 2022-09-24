module ResourcesHelper
  def tally_resources(resources)
    agencies = [] 
      resources.each do |r| 
        agencies << r.agency 
      end
    agencies.group_by(&:itself).transform_values(&:count)
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

  def tally_equipment(incident)
    resources = incident.resources.equipment.assigned
    types = resources.pluck(:agency, :position).uniq
    final = []
    types.each do |t|
      count = 0
      tally = 0
      resources.pluck(:agency, :position, :number_personnel).each do |r|
        if t == [r[0], r[1]]
          count += 1
          tally += r[2]
        end
      end
        final << [count, t[0], t[1], tally]
    end
    return final
  end

end
