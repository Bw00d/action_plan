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

end
