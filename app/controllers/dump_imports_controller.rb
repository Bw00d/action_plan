class DumpImportsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def new
    @time_zones = ActiveSupport::TimeZone.us_zones
    @default_zone = @incident.time_zone.presence || "Alaska"
  end

  def create
    if params[:dump].blank?
      redirect_to new_incident_dump_import_path(@incident), alert: "Choose a dump file to upload."
      return
    end

    result = IrocImporter.new(params[:dump].tempfile, time_zone: params[:time_zone].presence)
                         .import_into(@incident)

    redirect_to incident_requests_path(@incident),
                notice: "Imported #{result.requests_created} new requests, " \
                        "#{result.requests_updated} updated."
  rescue IrocImporter::DumpMismatch => e
    redirect_to new_incident_dump_import_path(@incident), alert: e.message
  rescue IrocImporter::MissingHeader => e
    redirect_to new_incident_dump_import_path(@incident), alert: "Invalid dump: #{e.message}"
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end
end
