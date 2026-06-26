# Creates the requests table holding one row per IROC IncidentRequests line.
# This is a mixed resource table: personnel (Overhead/Crew) carry name and
# employment fields; aircraft/equipment/supply lines leave those null.
#
# Match the Rails version below to your app.
class CreateRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :requests do |t|
      t.references :incident, null: false, foreign_key: true

      # IROC identifiers
      t.string :iroc_req_id, null: false   # ReqID  — unique per request line
      t.string :iroc_res_id                # ResID  — the assigned resource

      # Request / order
      t.boolean :root_req_flag
      t.string  :req_number_prefix         # A, C, E, O, S
      t.string  :req_number                # e.g. "E-24.1"
      t.string  :req_catalog_name          # Aircraft, Crew, Equipment, Overhead, Supply
      t.string  :req_category_name         # Engine, Fire Crew, Positions, ...

      # Resource / assignment
      t.string :res_name
      t.string :assignment_name
      t.string :res_prov_agency_abbrev
      t.string :res_prov_unit_code
      t.string :filled_catalog_item_code   # e.g. ENOP, FFT2
      t.string :filled_catalog_item_name   # e.g. Engine Operator
      t.string :employment_class           # Career, Casual Hire, ... (personnel only)
      t.string :jet_port
      t.datetime :mob_etd                  # mobilization ETD

      # Vendor / contract (populated only for vendor-owned resources)
      t.boolean :vendor_owned_flag
      t.string  :vendor_name
      t.string  :contract_type
      t.string  :contract_number

      # Person name parts (personnel only)
      t.string :last_name
      t.string :first_name
      t.string :middle_name

      t.timestamps
    end

    add_index :requests, :iroc_req_id, unique: true
    add_index :requests, :iroc_res_id
  end
end
