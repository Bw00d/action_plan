# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_07_10_085426) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.integer "plan_id"
    t.string "description"
    t.boolean "completed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "assignments", force: :cascade do |t|
    t.string "designator"
    t.text "control_operations"
    t.text "special_instructions"
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "commo_item_ids", array: true
    t.string "ops_period"
    t.string "resource_ids", array: true
    t.string "ops_personnel_ids", array: true
    t.bigint "org_unit_id"
    t.index ["org_unit_id"], name: "index_assignments_on_org_unit_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.string "description"
    t.boolean "attached", default: false
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "blocks", force: :cascade do |t|
    t.string "font_size", default: "h2"
    t.string "font_family"
    t.string "Arial"
    t.string "content"
    t.string "number"
    t.integer "cover_id"
    t.string "font_weight", default: "semi-bold"
    t.string "text_align", default: "center"
    t.string "text_style", default: "normal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "image_block", default: false
    t.string "bottom_padding", default: "0"
    t.boolean "is_blank", default: false
    t.integer "position"
    t.boolean "split_block", default: false
    t.string "pair_id"
    t.string "image_width"
    t.string "image_height"
    t.string "image_position_x"
  end

  create_table "checkins", force: :cascade do |t|
    t.integer "incident_id"
    t.string "agency"
    t.string "category"
    t.string "position"
    t.float "order_number"
    t.date "checkin_date"
    t.string "leader"
    t.string "contact_info"
    t.string "home_unit"
    t.string "other_quals"
    t.boolean "other_incident", default: false
    t.string "other_incident_name"
    t.date "first_day_worked"
    t.string "name"
    t.integer "number_personnel"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "commo_items", force: :cascade do |t|
    t.string "zone"
    t.string "ch_num"
    t.string "function"
    t.string "channel_name"
    t.string "assignment"
    t.string "rx_freq"
    t.string "rx_tone"
    t.string "tx_freq"
    t.string "tx_tone"
    t.string "mode"
    t.integer "commo_plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "commo_plans", force: :cascade do |t|
    t.integer "plan_id"
    t.string "date_prepared"
    t.string "ops_period"
    t.text "special_instructions"
    t.string "prepared_by"
    t.string "date_signed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "covers", force: :cascade do |t|
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "demob_notifications", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.bigint "resource_id", null: false
    t.bigint "demob_id"
    t.string "request_number"
    t.string "unit_id"
    t.string "name"
    t.date "actual_release_date"
    t.string "actual_release_time"
    t.string "return_travel_method"
    t.string "demob_city_state"
    t.boolean "ron", default: false
    t.string "ron_location"
    t.date "est_arrival_date"
    t.string "est_arrival_time"
    t.text "remarks"
    t.boolean "transmitted", default: false, null: false
    t.datetime "transmitted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["demob_id"], name: "index_demob_notifications_on_demob_id"
    t.index ["incident_id", "transmitted"], name: "index_demob_notifications_on_incident_id_and_transmitted"
    t.index ["incident_id"], name: "index_demob_notifications_on_incident_id"
    t.index ["resource_id"], name: "index_demob_notifications_on_resource_id"
    t.index ["transmitted"], name: "index_demob_notifications_on_transmitted"
  end

  create_table "demobs", force: :cascade do |t|
    t.integer "resource_id"
    t.text "remarks"
    t.date "edd"
    t.string "edt"
    t.string "destination"
    t.string "travel_method"
    t.boolean "manifest"
    t.boolean "manifest_number"
    t.boolean "ron"
    t.date "actual_release_date"
    t.string "actual_release_time"
    t.string "eta"
    t.string "contact_enroute"
    t.boolean "agency_notified"
    t.boolean "reassigned"
    t.string "new_incident"
    t.string "new_incident_number"
    t.string "new_order_number"
    t.string "prepared_by"
    t.string "pb_position"
    t.date "date"
    t.string "time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "new_location"
    t.date "estimated_arrival_date"
  end

  create_table "financial_codes", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.string "agency", null: false
    t.string "code", null: false
    t.integer "position", default: 0
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["incident_id", "agency"], name: "index_financial_codes_on_incident_id_and_agency", unique: true
    t.index ["incident_id", "position"], name: "index_financial_codes_on_incident_id_and_position"
    t.index ["incident_id"], name: "index_financial_codes_on_incident_id"
  end

  create_table "friendly_id_slugs", id: :serial, force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "incidents", force: :cascade do |t|
    t.string "name"
    t.string "p_code"
    t.string "number"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "size"
    t.string "financial_code"
    t.string "incident_type"
    t.string "complexity"
    t.string "status"
    t.string "cause"
    t.string "fuel_type"
    t.date "start_date"
    t.date "containment_date"
    t.date "control_date"
    t.date "out_date"
    t.integer "percent_contained"
    t.string "location"
    t.string "ownership"
    t.string "protection"
    t.string "latitude"
    t.string "longitude"
    t.string "ic"
    t.string "fire_behavior"
    t.string "iroc_inc_id"
    t.string "state"
    t.datetime "initial_date"
    t.string "agency_abbrev"
    t.string "disp_org_unit_code"
    t.boolean "merged_inc_flag"
    t.string "previous_inc_number"
    t.string "time_zone"
    t.decimal "cost", precision: 14, scale: 2
    t.index ["iroc_inc_id"], name: "index_incidents_on_iroc_inc_id", unique: true
  end

  create_table "incidents_users", id: false, force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.bigint "user_id", null: false
    t.index ["incident_id", "user_id"], name: "index_incidents_users_on_incident_id_and_user_id"
    t.index ["user_id", "incident_id"], name: "index_incidents_users_on_user_id_and_incident_id"
  end

  create_table "objectives", force: :cascade do |t|
    t.integer "plan_id"
    t.string "description"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "org_unit_assignments", force: :cascade do |t|
    t.bigint "org_unit_id", null: false
    t.bigint "resource_id", null: false
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["org_unit_id", "position"], name: "index_org_unit_assignments_on_org_unit_id_and_position"
    t.index ["org_unit_id"], name: "index_org_unit_assignments_on_org_unit_id"
    t.index ["resource_id"], name: "index_org_unit_assignments_on_resource_id", unique: true
  end

  create_table "org_units", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.bigint "parent_id"
    t.integer "kind", null: false
    t.string "name", null: false
    t.string "designator"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["incident_id", "kind"], name: "index_org_units_on_incident_id_and_kind"
    t.index ["incident_id"], name: "index_org_units_on_incident_id"
    t.index ["parent_id", "position"], name: "index_org_units_on_parent_id_and_position"
    t.index ["parent_id"], name: "index_org_units_on_parent_id"
  end

  create_table "plan_assignment_snapshots", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "org_unit_id"
    t.bigint "resource_id", null: false
    t.integer "position"
    t.string "designator_at_publish"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["org_unit_id"], name: "index_plan_assignment_snapshots_on_org_unit_id"
    t.index ["plan_id", "org_unit_id", "position"], name: "index_pa_snapshots_on_plan_unit_position"
    t.index ["plan_id"], name: "index_plan_assignment_snapshots_on_plan_id"
    t.index ["resource_id"], name: "index_plan_assignment_snapshots_on_resource_id"
  end

  create_table "plan_objectives", force: :cascade do |t|
    t.integer "plan_id"
    t.integer "objective_id"
  end

  create_table "plan_resources", force: :cascade do |t|
    t.integer "plan_id"
    t.integer "resource_id"
  end

  create_table "plans", force: :cascade do |t|
    t.date "date"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "situation"
    t.integer "incident_id"
    t.text "weather"
    t.text "general_safety"
    t.string "prepared_by"
    t.string "approved_by"
    t.boolean "org_list"
    t.boolean "assignment_list"
    t.boolean "comm_plan"
    t.boolean "med_plan"
    t.boolean "incident_map"
    t.boolean "travel_plan"
    t.date "date_prepare"
    t.string "time_prepared"
    t.string "ops_period"
    t.datetime "published_at"
    t.index ["published_at"], name: "index_plans_on_published_at"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "posted_at"
    t.integer "user_id"
    t.integer "incident_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.string "iroc_req_id", null: false
    t.string "iroc_res_id"
    t.boolean "root_req_flag"
    t.string "req_number_prefix"
    t.string "req_number"
    t.string "req_catalog_name"
    t.string "req_category_name"
    t.string "res_name"
    t.string "assignment_name"
    t.string "res_prov_agency_abbrev"
    t.string "res_prov_unit_code"
    t.string "filled_catalog_item_code"
    t.string "filled_catalog_item_name"
    t.string "employment_class"
    t.string "jet_port"
    t.datetime "mob_etd"
    t.boolean "vendor_owned_flag"
    t.string "vendor_name"
    t.string "contract_type"
    t.string "contract_number"
    t.string "last_name"
    t.string "first_name"
    t.string "middle_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["incident_id"], name: "index_requests_on_incident_id"
    t.index ["iroc_req_id"], name: "index_requests_on_iroc_req_id", unique: true
    t.index ["iroc_res_id"], name: "index_requests_on_iroc_res_id"
  end

  create_table "resources", force: :cascade do |t|
    t.string "name"
    t.string "leader"
    t.integer "number_personnel"
    t.string "position"
    t.string "agency"
    t.date "checkin_date"
    t.integer "incident_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.integer "order_number"
    t.integer "assignment_length"
    t.string "phone"
    t.string "email"
    t.text "comment"
    t.date "fwd"
    t.date "release_date"
    t.boolean "r_and_r", default: false
    t.string "jetport"
    t.string "return_city"
    t.string "return_state"
  end

  create_table "safety_messages", force: :cascade do |t|
    t.text "hazards"
    t.text "narrative"
    t.string "prepared_by"
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "date_prepared"
    t.string "time_prepared"
    t.string "ops_period"
  end

  create_table "schedules", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.string "meeting_name", null: false
    t.string "time"
    t.string "location"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["incident_id", "position"], name: "index_schedules_on_incident_id_and_position"
    t.index ["incident_id"], name: "index_schedules_on_incident_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "resource_name"
    t.string "position"
    t.string "staff"
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "units", force: :cascade do |t|
    t.boolean "selected"
    t.string "manager"
    t.string "remarks"
    t.string "name"
    t.integer "demob_id"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "role"
    t.string "first_name"
    t.string "last_name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "incident_ids", default: [], array: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assignments", "org_units"
  add_foreign_key "demob_notifications", "demobs"
  add_foreign_key "demob_notifications", "incidents"
  add_foreign_key "demob_notifications", "resources"
  add_foreign_key "financial_codes", "incidents"
  add_foreign_key "org_unit_assignments", "org_units"
  add_foreign_key "org_unit_assignments", "resources"
  add_foreign_key "org_units", "incidents"
  add_foreign_key "org_units", "org_units", column: "parent_id"
  add_foreign_key "plan_assignment_snapshots", "org_units"
  add_foreign_key "plan_assignment_snapshots", "plans"
  add_foreign_key "plan_assignment_snapshots", "resources"
  add_foreign_key "requests", "incidents"
  add_foreign_key "schedules", "incidents"
end
