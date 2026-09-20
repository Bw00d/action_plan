class SeedNon209OrgUnits < ActiveRecord::Migration[6.0]
  # Backfill a single root Non-209 org_unit per incident so the T-cards
  # board shows the new column for existing incidents. New incidents get
  # theirs via Incident#seed_non_209 (after_create).
  def up
    Incident.reset_column_information
    OrgUnit.reset_column_information

    Incident.find_each do |incident|
      next if incident.org_units.where(kind: OrgUnit.kinds[:non_209]).exists?

      incident.org_units.create!(
        kind:      :non_209,
        name:      'Non-209',
        parent_id: nil
      )
    end
  end

  def down
    OrgUnit.where(kind: OrgUnit.kinds[:non_209], name: 'Non-209', parent_id: nil)
           .destroy_all
  end
end
