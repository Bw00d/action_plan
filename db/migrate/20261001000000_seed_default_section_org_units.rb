class SeedDefaultSectionOrgUnits < ActiveRecord::Migration[6.0]
  # Backfill the Plans / Logistics / Finance / Operations section org
  # units AND the Command unit on existing incidents so the Resource
  # position auto-router has somewhere to route to. Idempotent: skips
  # anything already present.
  def up
    Incident.reset_column_information
    OrgUnit.reset_column_information

    section_kind = OrgUnit.kinds[:section]
    command_kind = OrgUnit.kinds[:command]

    Incident.find_each do |incident|
      Incident::DEFAULT_SECTION_NAMES.each do |name|
        next if incident.org_units.where(kind: section_kind, name: name).exists?
        incident.org_units.create!(kind: :section, name: name, parent_id: nil)
      rescue => e
        Rails.logger.warn "Incident##{incident.id} seed section '#{name}' failed: #{e.class}: #{e.message}"
      end

      unless incident.org_units.where(kind: command_kind).exists?
        begin
          incident.org_units.create!(kind: :command, name: 'Command', parent_id: nil)
        rescue => e
          Rails.logger.warn "Incident##{incident.id} seed Command failed: #{e.class}: #{e.message}"
        end
      end
    end
  end

  def down
    # No-op — don't destroy user data on rollback.
  end
end
