class CreateMedicalPlans < ActiveRecord::Migration[6.0]
  def change
    # Parent record — one per Plan. Holds section 8/9/10/11 header
    # fields; the five sub-tables below hold the repeatable sections.
    create_table :medical_plans do |t|
      t.references :plan, null: false, foreign_key: true, index: { unique: true }
      t.string  :prepared_by
      t.string  :prepared_at         # free text — matches other 20x forms
      t.string  :reviewed_by
      t.string  :reviewed_at
      t.timestamps
    end

    # Section 3 — ground ambulance services.
    create_table :medical_ambulances do |t|
      t.references :medical_plan, null: false, foreign_key: true
      t.string  :name
      t.string  :address
      t.string  :phone_ems_freq
      t.boolean :als, default: false, null: false
      t.integer :position
      t.timestamps
    end

    # Section 4 — air ambulance services.
    create_table :medical_air_ambulances do |t|
      t.references :medical_plan, null: false, foreign_key: true
      t.string  :name
      t.string  :phone
      t.string  :aircraft_capability
      t.integer :position
      t.timestamps
    end

    # Section 5 — hospitals.
    create_table :medical_hospitals do |t|
      t.references :medical_plan, null: false, foreign_key: true
      t.string  :name
      t.string  :address
      t.string  :lat
      t.string  :long
      t.string  :vhf
      t.string  :travel_air
      t.string  :travel_gnd
      t.string  :phone
      t.boolean :helipad, default: false, null: false
      t.string  :level_of_care
      t.integer :position
      t.timestamps
    end

    # Section 6 (division|branch|group) + Section 7 (remote camps) share
    # the same block of fields on the printed form, so one table with a
    # `kind` enum covers both. Section 7 additionally has a POC field
    # (nullable for section 6 entries).
    create_table :medical_zones do |t|
      t.references :medical_plan, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0  # 0 = division, 1 = camp
      t.string  :name
      t.string  :poc
      t.text    :ems_responders
      t.text    :equipment
      t.string  :medical_channel
      t.string  :eta_air
      t.string  :eta_ground
      t.string  :helispot
      t.string  :helispot_lat
      t.string  :helispot_long
      t.integer :position
      t.timestamps
      t.index [:medical_plan_id, :kind, :position], name: 'idx_med_zones_plan_kind_pos'
    end
  end
end
