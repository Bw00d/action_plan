class AddRnrBoardToIncidents < ActiveRecord::Migration[6.0]
  # Incident#seed_rnr_bucket covers new incidents; this adds the R&R
  # column to existing ones. 6 = OrgUnit.kinds[:rnr].
  def up
    execute <<~SQL
      INSERT INTO org_units (incident_id, kind, name, position, created_at, updated_at)
      SELECT incidents.id, 6, 'R&R', 1, NOW(), NOW()
      FROM incidents
      WHERE NOT EXISTS (
        SELECT 1 FROM org_units
        WHERE org_units.incident_id = incidents.id AND org_units.kind = 6
      )
    SQL
  end

  def down
    execute 'DELETE FROM org_units WHERE kind = 6'
  end
end
