class CreateFinancialCodes < ActiveRecord::Migration[6.0]
  def change
    create_table :financial_codes do |t|
      t.references :incident, null: false, foreign_key: true
      t.string  :agency, null: false     # e.g. BLM, USFS, SOA, LDP, NWC/SZS, WA-DNR
      t.string  :code,   null: false     # the actual code value
      t.integer :position, default: 0
      t.text    :notes                   # optional context ("LDP = ...")
      t.timestamps
    end

    add_index :financial_codes, [:incident_id, :agency], unique: true
    add_index :financial_codes, [:incident_id, :position]
  end
end
