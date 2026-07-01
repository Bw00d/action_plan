class RequestsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def index
    @requests = @incident.requests.order(:req_catalog_name, :req_number_prefix, :req_number)

    # Split parents vs children globally (children can be a different catalog
    # than their parent — e.g. a Crew parent with Overhead crew members).
    all_parents = []
    @children_by_parent = Hash.new { |h, k| h[k] = [] }
    @requests.each do |r|
      if r.req_number.to_s.include?('.')
        parent_num = r.req_number.sub(/\.[^.]+\z/, '')
        @children_by_parent[parent_num] << r
      else
        all_parents << r
      end
    end

    # Promote orphan subordinates (parent record missing) to top-level so
    # nothing goes unrendered.
    parent_numbers = all_parents.map(&:req_number).to_set
    @children_by_parent.keys.reject { |k| parent_numbers.include?(k) }.each do |orphan|
      all_parents.concat(@children_by_parent.delete(orphan))
    end

    # Group parents into tables by their own catalog. Their children appear
    # beneath them here regardless of the children's catalog.
    @parents_by_catalog   = all_parents.group_by(&:req_catalog_name)
    @counts_by_catalog    = @requests.group_by(&:req_catalog_name).transform_values(&:size)
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end
end
