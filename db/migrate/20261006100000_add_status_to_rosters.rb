class AddStatusToRosters < ActiveRecord::Migration[6.0]
  # Per-subordinate status so the tally only counts people actually
  # present at the incident.
  #   C = Checked in — present, count in personnel_by_agency
  #   F = Filled     — on roster but not physically here (common with
  #                    long crew rosters that rotate in and out)
  # Default C so existing rows match today's behavior exactly.
  def change
    add_column :rosters, :status, :string, default: 'C', null: false
    add_index :rosters, :status
  end
end
