class CreateRemoteCheckins < ActiveRecord::Migration[6.0]
  def change
    # Opaque per-incident token for the public conversational check-in
    # form. Shared with arriving resources so they can self-report
    # before the Plans section formally checks them in. Rotatable from
    # the incident settings when a token leaks or an incident wraps.
    add_column :incidents, :remote_checkin_token, :string
    add_index  :incidents, :remote_checkin_token, unique: true

    create_table :remote_checkins do |t|
      t.references :incident,           null: false, foreign_key: true, index: true
      # Matched request (via req_number lookup at submit time). Nullable
      # — the resource may have arrived before dispatch created the
      # request; the admin reconciles later on the review screen.
      t.references :request,            null: true,  foreign_key: true, index: true
      # Filled in when an admin clicks Check In and the submission is
      # promoted into a real Resource via RequestCheckinsController.
      t.bigint     :promoted_resource_id, index: true

      # 0=pending, 1=promoted, 2=dismissed (enum on model).
      t.integer    :status, null: false, default: 0, index: true

      # ── Fields captured by the public form (match the PDF flow) ──
      t.string  :req_number_raw     # exactly what the resource typed, in case lookup fails
      t.string  :category           # OVERHEAD / CREW / EQUIPMENT / AIRCRAFT (derived from prefix)
      t.string  :name               # resource name (for CREW: crew name)
      t.string  :position
      t.string  :agency
      t.string  :agency_address
      t.string  :email
      t.string  :leader
      t.string  :phone              # cell number
      t.string  :emergency_contact
      t.date    :mobilization_date
      t.boolean :from_other_incident, default: false, null: false
      t.string  :other_incident_name
      t.string  :other_incident_req_number
      t.date    :first_day_worked
      t.date    :first_work_day
      t.string  :demob_city
      t.string  :demob_state
      t.string  :transportation_method
      t.integer :number_personnel

      # OVERHEAD branch: were they a single resource (yes) or a group (no).
      t.boolean :overhead_single_resource
      # Free text: for crews/equipment/overhead-non-single, the names of
      # other personnel (one per line). The reviewer uses this to seed
      # the roster when they promote.
      t.text    :other_crew_members

      t.datetime :submitted_at
      t.datetime :promoted_at

      t.timestamps
    end

    # Backfill tokens for existing incidents. Done inline so the
    # public URL works immediately after deploy; the admin can rotate
    # later from the incident settings.
    reversible do |dir|
      dir.up do
        say_with_time "Backfilling remote_checkin_token on existing incidents" do
          Incident.reset_column_information
          Incident.where(remote_checkin_token: nil).find_each do |inc|
            inc.update_columns(remote_checkin_token: SecureRandom.urlsafe_base64(16))
          end
        end
      end
    end
  end
end
