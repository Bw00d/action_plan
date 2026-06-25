require "nokogiri"

# Imports an IROC / e-ISuite Cognos dump (the dataSet XML with IncidentHeader
# and IncidentRequests tables) into your Rails app.
#
# Two entry points:
#
#   # Mode 1 — create (or refresh) the incident from the dump header, then
#   # import all of its request rows.
#   IrocImporter.new("tmp/Starry.xml").create_incident!
#
#   # Mode 2 — add the dump's request rows to an incident you already have.
#   incident = Incident.find(42)
#   IrocImporter.new(uploaded_file).import_into(incident)
#
# `source` may be a file path, a raw XML string, or any IO (e.g. an
# ActionDispatch::Http::UploadedFile).
#
# Idempotency: incidents are matched on IncID, requests on ReqID. Re-running a
# dump updates existing rows in place rather than duplicating them, and adds any
# request lines that are new. (To make it strictly insert-only, see the marked
# line in #import_requests!.)
class IrocImporter
  class DumpMismatch < StandardError; end
  class MissingHeader < StandardError; end

  Result = Struct.new(:incident, :requests_created, :requests_updated, keyword_init: true) do
    def requests_total
      requests_created + requests_updated
    end
  end

  def initialize(source)
    @doc = load_document(source)
  end

  # Mode 1: build/refresh the Incident from the header, then import requests.
  def create_incident!
    ActiveRecord::Base.transaction do
      incident = upsert_incident!
      created, updated = import_requests!(incident)
      Result.new(incident:, requests_created: created, requests_updated: updated)
    end
  end

  # Mode 2: import this dump's request rows into an existing incident.
  # Raises DumpMismatch if the dump is for a different incident; pass
  # match: false to skip that safety check.
  def import_into(incident, match: true)
    if match && incident.iroc_inc_id.present? &&
       incident.iroc_inc_id != header_attributes[:iroc_inc_id]
      raise DumpMismatch,
            "Dump is for IncID #{header_attributes[:iroc_inc_id]} " \
            "but incident ##{incident.id} is #{incident.iroc_inc_id}"
    end

    ActiveRecord::Base.transaction do
      created, updated = import_requests!(incident)
      Result.new(incident:, requests_created: created, requests_updated: updated)
    end
  end

  private

  # ── Incident ────────────────────────────────────────────────────────────

  def upsert_incident!
    attrs = header_attributes
    incident = Incident.find_or_initialize_by(iroc_inc_id: attrs[:iroc_inc_id])
    incident.assign_attributes(attrs)
    incident.save!
    incident
  end

  def header_attributes
    @header_attributes ||= begin
      row = header_row
      {
        iroc_inc_id:         field(row, "IncID"),
        inc_number:          field(row, "IncNumber"),
        name:                field(row, "IncName"),
        inc_type:            field(row, "IncType"),
        state:               field(row, "IncState"),
        initial_date:        time(field(row, "InitialDate")),
        agency_abbrev:       field(row, "IncAgencyAbbrev"),
        disp_org_unit_code:  field(row, "IncDispOrgUnitCode"),
        merged_inc_flag:     yn(field(row, "MergedIncFlag")),
        previous_inc_number: field(row, "PreviousIncNumber")
      }
    end
  end

  # ── Requests ────────────────────────────────────────────────────────────

  def import_requests!(incident)
    created = 0
    updated = 0

    request_rows.each do |row|
      attrs = request_attributes(row)
      request = incident.requests.find_or_initialize_by(iroc_req_id: attrs[:iroc_req_id])
      new_record = request.new_record?

      # For strictly insert-only behavior, replace the block below with:
      #   next unless new_record
      #   request.assign_attributes(attrs); request.save!; created += 1
      request.assign_attributes(attrs)
      if new_record
        request.save!
        created += 1
      elsif request.changed?
        request.save!
        updated += 1
      end
    end

    [created, updated]
  end

  def request_attributes(row)
    {
      iroc_req_id:            field(row, "ReqID"),
      iroc_res_id:            field(row, "ResID"),
      root_req_flag:          yn(field(row, "RootReqFlag")),
      req_number_prefix:      field(row, "ReqNumberPrefix"),
      req_number:             field(row, "ReqNumber"),
      req_catalog_name:       field(row, "ReqCatalogName"),
      req_category_name:      field(row, "ReqCategoryName"),
      res_name:               field(row, "ResName"),
      assignment_name:        field(row, "AssignmentName"),
      res_prov_agency_abbrev: field(row, "ResProvAgencyAbbrev"),
      res_prov_unit_code:     field(row, "ResProvUnitCode"),
      filled_catalog_item_code: field(row, "FilledCatalogItemCode"),
      filled_catalog_item_name: field(row, "FilledCatalogItemName"),
      employment_class:       field(row, "EmploymentClass"),
      jet_port:               field(row, "JetPort"),
      mob_etd:                time(field(row, "MobETD")),
      vendor_owned_flag:      yn(field(row, "VendorOwnedFlag")),
      vendor_name:            field(row, "VendorName"),
      contract_type:          field(row, "ContractType"),
      contract_number:        field(row, "ContractNumber"),
      last_name:              field(row, "LastName"),
      first_name:             field(row, "FirstName"),
      middle_name:            field(row, "MiddleName")
    }
  end

  # ── XML helpers ───────────────────────────────────────────────────────────

  def load_document(source)
    xml =
      if source.respond_to?(:read)
        source.read
      elsif source.is_a?(String) && File.exist?(source)
        File.read(source)
      else
        source.to_s
      end

    doc = Nokogiri::XML(xml)
    doc.remove_namespaces! # drop the Cognos namespace so plain xpath works
    doc
  end

  def header_row
    table("IncidentHeader")&.at_xpath("row") ||
      raise(MissingHeader, "No IncidentHeader/row found in dump")
  end

  def request_rows
    table("IncidentRequests")&.xpath("row") || []
  end

  def table(table_id)
    @doc.xpath("//dataTable").find { |t| t.at_xpath("id")&.text == table_id }
  end

  # Returns nil for missing or empty (<Tag/>) elements.
  def field(row, name)
    row.at_xpath(name)&.text.presence
  end

  # IROC booleans come through as "Yes"/"No".
  def yn(value)
    return nil if value.nil?

    %w[Yes Y true True].include?(value)
  end

  # Dump timestamps have nanosecond precision and no timezone. Parse them in the
  # app zone (set config.time_zone = "Alaska" for these incidents).
  def time(value)
    return nil if value.blank?

    Time.zone ? Time.zone.parse(value) : Time.parse(value)
  end
end
