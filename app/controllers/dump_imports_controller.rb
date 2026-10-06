class DumpImportsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  # Trimmed to actual US-state zones only. ActiveSupport's built-in
  # .us_zones returns ~20 entries including Mexico/Canada/Pacific-island
  # zones that share US offsets (Mazatlan, Chihuahua, Saskatchewan,
  # Samoa, etc) — unhelpful noise in the IROC-dump importer.
  US_ZONE_NAMES = [
    'Hawaii', 'Alaska',
    'Pacific Time (US & Canada)',
    'Mountain Time (US & Canada)', 'Arizona',
    'Central Time (US & Canada)',
    'Eastern Time (US & Canada)', 'Indiana (East)'
  ].freeze

  def new
    @time_zones = US_ZONE_NAMES.map { |n| ActiveSupport::TimeZone[n] }.compact
    # Prefer the incident's own zone when set, then the signed-in user's
    # detected zone (populated by user_timezone.js on first page load),
    # then Alaska as a last-ditch fallback.
    @default_zone = @incident.time_zone.presence ||
                    current_user&.time_zone.presence ||
                    "Alaska"
  end

  def create
    if params[:dump].blank?
      redirect_to new_incident_dump_import_path(@incident), alert: "Choose a dump file to upload."
      return
    end

    result = IrocImporter.new(params[:dump].tempfile, time_zone: params[:time_zone].presence)
                         .import_into(@incident)

    redirect_to incident_requests_path(@incident),
                notice: "Added #{result.requests_created} new request#{'s' if result.requests_created != 1}. " \
                        "Skipped #{result.requests_skipped} already present."
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
