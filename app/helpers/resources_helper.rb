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
    resources.pluck(:agency, :position, :number_personnel)
  end

end
