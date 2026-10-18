class CreateAirOperations < ActiveRecord::Migration[6.0]
  def change
    # One air_operations record per plan — the ICS 220 WF Air Operations
    # Summary. Repeatable sections (helicopters / supervision / UAS)
    # live in the three sub-tables below.
    create_table :air_operations do |t|
      t.references :plan, null: false, foreign_key: true, index: { unique: true }

      # Sections 1-8 — header. Incident name comes from @incident.name,
      # operational period from the Plan (shared with 206, 204, etc.).
      t.string :date_prepared
      t.string :time_prepared
      t.string :prepared_by
      t.string :sunrise
      t.string :sunset
      t.string :pumpkin_time
      t.string :shutdown

      # Section 9 — free-form notes about the operational period.
      t.text   :general_remarks

      # Section 10 — Helibase.
      t.string :helibase_name
      t.string :helibase_lat
      t.string :helibase_long

      # Section 11 — TFR.
      t.string :tfr_notam
      t.string :tfr_altitude
      t.string :tfr_frequency
      t.string :tfr_hours

      # Section 12 — Extraction/Medevac grid (3 columns × 4 rows) +
      # the "Request Extraction/Medevac Through" free-text box.
      %i[medevac shorthaul hoist].each do |col|
        t.string "#{col}_faa"
        t.string "#{col}_phone"
        t.string "#{col}_location"
        t.text   "#{col}_capabilities"
      end
      t.text   :request_through

      # Section 13 — Incident Frequencies (fixed 8 rows × 5 cols).
      %w[aa_tfr aa_rotor aa_briefing ag_primary ag_secondary ag_tactical deck tolc].each do |row|
        t.string "freq_#{row}_rx"
        t.string "freq_#{row}_tone"
        t.string "freq_#{row}_tx"
        t.string "freq_#{row}_tx_tone"
        t.string "freq_#{row}_mode"
      end

      # Section 14 — Position (fixed 5 rows × 2 cols).
      %w[aobd asgs hebm hlco uao].each do |role|
        t.string "pos_#{role}_name"
        t.string "pos_#{role}_phone"
      end

      # Section 15 — Equipment/Supplies.
      t.text :equipment_supplies

      t.timestamps
    end

    # Section 16 — Helicopters (repeatable rows).
    create_table :air_ops_helicopters do |t|
      t.references :air_operation, null: false, foreign_key: true
      t.string  :faa_number
      t.string  :aircraft_type
      t.string  :make_model
      t.string  :helibase
      t.string  :start_time
      t.string  :available
      t.text    :remarks
      t.integer :position
      t.timestamps
    end

    # Section 17 — Aerial Supervision: Air Attack / Helicopter Coord.
    create_table :air_ops_supervisions do |t|
      t.references :air_operation, null: false, foreign_key: true
      t.string  :faa_number
      t.string  :call_sign
      t.string  :make_model
      t.string  :base
      t.string  :start_time
      t.string  :available
      t.text    :remarks
      t.integer :position
      t.timestamps
    end

    # Section 18 — Unmanned Aircraft Systems (UAS).
    create_table :air_ops_uas_entries do |t|
      t.references :air_operation, null: false, foreign_key: true
      t.string  :identifier
      t.string  :cat_type
      t.string  :make_model
      t.string  :location
      t.string  :start_time
      t.string  :available
      t.string  :leader_contact
      t.text    :remarks
      t.integer :position
      t.timestamps
    end
  end
end
