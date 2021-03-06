# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20200620235944) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "actions", force: :cascade do |t|
    t.string "time"
    t.string "note"
    t.integer "plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "objectives", force: :cascade do |t|
    t.integer "plan_id"
    t.string "description"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "resources", force: :cascade do |t|
    t.string "name"
    t.string "leader"
    t.integer "number_personnel"
    t.string "position"
    t.string "agency"
    t.date "lwd"
    t.date "checkin_date"
    t.integer "incident_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.integer "order_number"
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
  end

  create_table "teams", force: :cascade do |t|
    t.string "resource_name"
    t.string "position"
    t.string "staff"
    t.integer "plan_id"
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

end
