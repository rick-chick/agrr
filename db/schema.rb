# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_02_220000) do
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
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "crop_pests", force: :cascade do |t|
    t.integer "crop_id", null: false
    t.integer "pest_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_id", "pest_id"], name: "index_crop_pests_on_crop_id_and_pest_id", unique: true
    t.index ["crop_id"], name: "index_crop_pests_on_crop_id"
    t.index ["pest_id"], name: "index_crop_pests_on_pest_id"
  end

  create_table "crop_stages", force: :cascade do |t|
    t.integer "crop_id", null: false
    t.string "name", null: false
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_id", "order"], name: "index_crop_stages_on_crop_id_and_order", unique: true
    t.index ["crop_id"], name: "index_crop_stages_on_crop_id"
  end

  create_table "crops", force: :cascade do |t|
    t.integer "user_id"
    t.string "name", null: false
    t.string "variety"
    t.boolean "is_reference", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "area_per_unit"
    t.float "revenue_per_area"
    t.text "groups"
    t.string "region"
    t.index ["region"], name: "index_crops_on_region"
    t.index ["user_id"], name: "index_crops_on_user_id"
  end

  create_table "cultivation_plan_crops", force: :cascade do |t|
    t.integer "cultivation_plan_id", null: false
    t.string "name", null: false
    t.string "variety"
    t.float "area_per_unit"
    t.float "revenue_per_area"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "crop_id"
    t.index ["crop_id"], name: "index_cultivation_plan_crops_on_crop_id"
    t.index ["cultivation_plan_id"], name: "index_cultivation_plan_crops_on_cultivation_plan_id"
  end

  create_table "cultivation_plan_fields", force: :cascade do |t|
    t.integer "cultivation_plan_id", null: false
    t.string "name", null: false
    t.float "area", null: false
    t.float "daily_fixed_cost"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cultivation_plan_id"], name: "index_cultivation_plan_fields_on_cultivation_plan_id"
  end

  create_table "cultivation_plans", force: :cascade do |t|
    t.integer "farm_id", null: false
    t.integer "user_id"
    t.string "session_id"
    t.float "total_area", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "optimization_phase"
    t.text "optimization_phase_message"
    t.date "planning_start_date"
    t.date "planning_end_date"
    t.decimal "total_profit"
    t.decimal "total_revenue"
    t.decimal "total_cost"
    t.decimal "optimization_time"
    t.string "algorithm_used"
    t.boolean "is_optimal"
    t.text "optimization_summary"
    t.text "predicted_weather_data"
    t.string "plan_type", default: "public", null: false
    t.string "plan_name"
    t.integer "plan_year"
    t.index ["farm_id", "user_id", "plan_year"], name: "index_cultivation_plans_on_farm_user_year_unique", unique: true, where: "plan_type = 'private'"
    t.index ["farm_id"], name: "index_cultivation_plans_on_farm_id"
    t.index ["plan_type"], name: "index_cultivation_plans_on_plan_type"
    t.index ["session_id"], name: "index_cultivation_plans_on_session_id"
    t.index ["status"], name: "index_cultivation_plans_on_status"
    t.index ["user_id", "plan_name", "plan_year"], name: "index_cultivation_plans_on_user_plan_name_year", where: "plan_type = 'private'"
    t.index ["user_id", "plan_year"], name: "index_cultivation_plans_on_user_id_and_plan_year", where: "plan_type = 'private'"
    t.index ["user_id"], name: "index_cultivation_plans_on_user_id"
  end

  create_table "farm_sizes", force: :cascade do |t|
    t.string "name", null: false
    t.integer "area_sqm", null: false
    t.integer "display_order", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_farm_sizes_on_active"
    t.index ["display_order"], name: "index_farm_sizes_on_display_order"
  end

  create_table "farms", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "weather_data_status", default: "pending", null: false
    t.integer "weather_data_fetched_years", default: 0, null: false
    t.integer "weather_data_total_years", default: 0, null: false
    t.text "weather_data_last_error"
    t.datetime "last_broadcast_at"
    t.integer "weather_location_id"
    t.boolean "is_reference", default: false, null: false
    t.string "region"
    t.text "predicted_weather_data"
    t.index ["is_reference"], name: "index_farms_on_is_reference", where: "is_reference = true"
    t.index ["region"], name: "index_farms_on_region"
    t.index ["user_id", "name"], name: "index_farms_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_farms_on_user_id"
    t.index ["weather_data_status"], name: "index_farms_on_weather_data_status"
    t.index ["weather_location_id"], name: "index_farms_on_weather_location_id"
  end

  create_table "fertilizes", force: :cascade do |t|
    t.string "name", null: false
    t.float "n"
    t.float "p"
    t.float "k"
    t.text "description"
    t.boolean "is_reference", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "package_size"
    t.index ["name"], name: "index_fertilizes_on_name", unique: true
  end

  create_table "field_cultivations", force: :cascade do |t|
    t.integer "cultivation_plan_id", null: false
    t.float "area", null: false
    t.date "start_date"
    t.date "completion_date"
    t.integer "cultivation_days"
    t.float "estimated_cost"
    t.string "status", default: "pending", null: false
    t.text "optimization_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cultivation_plan_field_id"
    t.integer "cultivation_plan_crop_id"
    t.index ["cultivation_plan_crop_id"], name: "index_field_cultivations_on_cultivation_plan_crop_id"
    t.index ["cultivation_plan_field_id"], name: "index_field_cultivations_on_cultivation_plan_field_id"
    t.index ["cultivation_plan_id"], name: "index_field_cultivations_on_cultivation_plan_id"
    t.index ["cultivation_plan_id"], name: "index_field_cultivations_on_cultivation_plan_id_and_field_id"
    t.index ["status"], name: "index_field_cultivations_on_status"
  end

  create_table "fields", force: :cascade do |t|
    t.integer "farm_id", null: false
    t.integer "user_id"
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "area"
    t.float "daily_fixed_cost"
    t.string "region"
    t.index ["farm_id", "name"], name: "index_fields_on_farm_id_and_name"
    t.index ["farm_id"], name: "index_fields_on_farm_id"
    t.index ["region"], name: "index_fields_on_region"
    t.index ["user_id", "farm_id", "name"], name: "index_fields_on_user_id_and_farm_id_and_name", unique: true
    t.index ["user_id"], name: "index_fields_on_user_id"
  end

  create_table "free_crop_plans", force: :cascade do |t|
    t.integer "farm_id", null: false
    t.integer "crop_id", null: false
    t.string "session_id"
    t.integer "area_sqm", null: false
    t.string "status", default: "pending", null: false
    t.text "plan_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_id"], name: "index_free_crop_plans_on_crop_id"
    t.index ["farm_id"], name: "index_free_crop_plans_on_farm_id"
    t.index ["session_id"], name: "index_free_crop_plans_on_session_id"
    t.index ["status"], name: "index_free_crop_plans_on_status"
  end

  create_table "interaction_rules", force: :cascade do |t|
    t.string "rule_type", null: false
    t.string "source_group", null: false
    t.string "target_group", null: false
    t.decimal "impact_ratio", precision: 5, scale: 2, null: false
    t.boolean "is_directional", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_reference", default: false, null: false
    t.string "region"
    t.index ["is_reference"], name: "index_interaction_rules_on_is_reference"
    t.index ["region"], name: "index_interaction_rules_on_region"
    t.index ["rule_type", "source_group", "target_group"], name: "index_interaction_rules_on_type_and_groups"
    t.index ["rule_type"], name: "index_interaction_rules_on_rule_type"
    t.index ["source_group"], name: "index_interaction_rules_on_source_group"
    t.index ["target_group"], name: "index_interaction_rules_on_target_group"
    t.index ["user_id", "is_reference"], name: "index_interaction_rules_on_user_id_and_is_reference"
    t.index ["user_id"], name: "index_interaction_rules_on_user_id"
  end

  create_table "pest_control_methods", force: :cascade do |t|
    t.integer "pest_id", null: false
    t.string "method_type", null: false
    t.string "method_name", null: false
    t.text "description"
    t.string "timing_hint"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["method_type"], name: "index_pest_control_methods_on_method_type"
    t.index ["pest_id"], name: "index_pest_control_methods_on_pest_id"
  end

  create_table "pest_temperature_profiles", force: :cascade do |t|
    t.integer "pest_id", null: false
    t.float "base_temperature"
    t.float "max_temperature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pest_id"], name: "index_pest_temperature_profiles_on_pest_id"
  end

  create_table "pest_thermal_requirements", force: :cascade do |t|
    t.integer "pest_id", null: false
    t.float "required_gdd"
    t.float "first_generation_gdd"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pest_id"], name: "index_pest_thermal_requirements_on_pest_id"
  end

  create_table "pesticide_application_details", force: :cascade do |t|
    t.integer "pesticide_id", null: false
    t.string "dilution_ratio"
    t.float "amount_per_m2"
    t.string "amount_unit"
    t.string "application_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pesticide_id"], name: "index_pesticide_application_details_on_pesticide_id"
  end

  create_table "pesticide_usage_constraints", force: :cascade do |t|
    t.integer "pesticide_id", null: false
    t.float "min_temperature"
    t.float "max_temperature"
    t.float "max_wind_speed_m_s"
    t.integer "max_application_count"
    t.integer "harvest_interval_days"
    t.text "other_constraints"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pesticide_id"], name: "index_pesticide_usage_constraints_on_pesticide_id"
  end

  create_table "pesticides", force: :cascade do |t|
    t.string "pesticide_id", null: false
    t.string "name", null: false
    t.string "active_ingredient"
    t.text "description"
    t.boolean "is_reference", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "crop_id", null: false
    t.integer "pest_id", null: false
    t.index ["crop_id", "pest_id", "pesticide_id"], name: "index_pesticides_on_crop_pest_pesticide_id", unique: true
    t.index ["crop_id"], name: "index_pesticides_on_crop_id"
    t.index ["is_reference"], name: "index_pesticides_on_is_reference"
    t.index ["pest_id"], name: "index_pesticides_on_pest_id"
    t.index ["pesticide_id"], name: "index_pesticides_on_pesticide_id", unique: true
  end

  create_table "pests", force: :cascade do |t|
    t.string "pest_id", null: false
    t.string "name", null: false
    t.string "name_scientific"
    t.string "family"
    t.string "order"
    t.text "description"
    t.string "occurrence_season"
    t.boolean "is_reference", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_reference"], name: "index_pests_on_is_reference"
    t.index ["pest_id"], name: "index_pests_on_pest_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.integer "user_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", limit: 1024, null: false
    t.binary "value", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "key_hash", limit: 8, null: false
    t.integer "byte_size", limit: 4, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "sunshine_requirements", force: :cascade do |t|
    t.integer "crop_stage_id", null: false
    t.float "minimum_sunshine_hours"
    t.float "target_sunshine_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_stage_id"], name: "index_sunshine_requirements_on_crop_stage_id"
  end

  create_table "temperature_requirements", force: :cascade do |t|
    t.integer "crop_stage_id", null: false
    t.float "base_temperature"
    t.float "optimal_min"
    t.float "optimal_max"
    t.float "low_stress_threshold"
    t.float "high_stress_threshold"
    t.float "frost_threshold"
    t.float "sterility_risk_threshold"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "max_temperature"
    t.index ["crop_stage_id"], name: "index_temperature_requirements_on_crop_stage_id"
  end

  create_table "thermal_requirements", force: :cascade do |t|
    t.integer "crop_stage_id", null: false
    t.float "required_gdd"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_stage_id"], name: "index_thermal_requirements_on_crop_stage_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "google_id"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin"
    t.boolean "is_anonymous", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "is_anonymous = false"
    t.index ["google_id"], name: "index_users_on_google_id", unique: true, where: "is_anonymous = false"
  end

  create_table "weather_data", force: :cascade do |t|
    t.integer "weather_location_id", null: false
    t.date "date"
    t.decimal "temperature_max"
    t.decimal "temperature_min"
    t.decimal "temperature_mean"
    t.decimal "precipitation"
    t.decimal "sunshine_hours"
    t.decimal "wind_speed"
    t.integer "weather_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["weather_location_id", "date"], name: "index_weather_data_on_location_and_date", unique: true
    t.index ["weather_location_id"], name: "index_weather_data_on_weather_location_id"
  end

  create_table "weather_locations", force: :cascade do |t|
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "elevation"
    t.string "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "crop_pests", "crops"
  add_foreign_key "crop_pests", "pests"
  add_foreign_key "crop_stages", "crops"
  add_foreign_key "crops", "users"
  add_foreign_key "cultivation_plan_crops", "crops"
  add_foreign_key "cultivation_plan_crops", "cultivation_plans"
  add_foreign_key "cultivation_plan_fields", "cultivation_plans"
  add_foreign_key "cultivation_plans", "farms"
  add_foreign_key "cultivation_plans", "users"
  add_foreign_key "farms", "users"
  add_foreign_key "farms", "weather_locations"
  add_foreign_key "field_cultivations", "cultivation_plan_crops"
  add_foreign_key "field_cultivations", "cultivation_plan_fields"
  add_foreign_key "field_cultivations", "cultivation_plans"
  add_foreign_key "fields", "farms"
  add_foreign_key "fields", "users"
  add_foreign_key "free_crop_plans", "crops"
  add_foreign_key "free_crop_plans", "farms"
  add_foreign_key "interaction_rules", "users"
  add_foreign_key "pest_control_methods", "pests"
  add_foreign_key "pest_temperature_profiles", "pests"
  add_foreign_key "pest_thermal_requirements", "pests"
  add_foreign_key "pesticide_application_details", "pesticides"
  add_foreign_key "pesticide_usage_constraints", "pesticides"
  add_foreign_key "pesticides", "crops"
  add_foreign_key "pesticides", "pests"
  add_foreign_key "sessions", "users"
  add_foreign_key "sunshine_requirements", "crop_stages"
  add_foreign_key "temperature_requirements", "crop_stages"
  add_foreign_key "thermal_requirements", "crop_stages"
  add_foreign_key "weather_data", "weather_locations"
end
