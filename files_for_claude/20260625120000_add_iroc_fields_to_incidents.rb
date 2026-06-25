# Adds the fields the IROC dump's IncidentHeader provides to your existing
# incidents table. Guarded with column_exists? so it's safe to run even if you
# already have some of these columns under different names — delete the lines
# you don't need and reconcile names to match your model.
#
# Match the Rails version below to your app (e.g. [7.0], [7.2], [8.0]).
class AddIrocFieldsToIncidents < ActiveRecord::Migration[7.1]
  def change
    add_column :incidents, :iroc_inc_id,        :string unless column_exists?(:incidents, :iroc_inc_id)
    add_column :incidents, :inc_number,         :string unless column_exists?(:incidents, :inc_number)
    add_column :incidents, :name,               :string unless column_exists?(:incidents, :name)
    add_column :incidents, :inc_type,           :string unless column_exists?(:incidents, :inc_type)
    add_column :incidents, :state,              :string unless column_exists?(:incidents, :state)
    add_column :incidents, :initial_date,       :datetime unless column_exists?(:incidents, :initial_date)
    add_column :incidents, :agency_abbrev,      :string unless column_exists?(:incidents, :agency_abbrev)
    add_column :incidents, :disp_org_unit_code, :string unless column_exists?(:incidents, :disp_org_unit_code)
    add_column :incidents, :merged_inc_flag,    :boolean unless column_exists?(:incidents, :merged_inc_flag)
    add_column :incidents, :previous_inc_number, :string unless column_exists?(:incidents, :previous_inc_number)

    add_index :incidents, :iroc_inc_id, unique: true unless index_exists?(:incidents, :iroc_inc_id)
  end
end
