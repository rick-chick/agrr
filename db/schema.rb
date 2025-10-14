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

ActiveRecord::Schema[8.0].define(version: 2025_10_13_072347) do
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
    t.string "agrr_crop_id"
    t.index ["agrr_crop_id"], name: "index_crops_on_agrr_crop_id"
    t.index ["user_id"], name: "index_crops_on_user_id"
  end

  create_table "cultivation_plan_crops", force: :cascade do |t|
    t.integer "cultivation_plan_id", null: false
    t.string "name", null: false
    t.string "variety"
    t.float "area_per_unit"
    t.float "revenue_per_area"
    t.string "agrr_crop_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["farm_id"], name: "index_cultivation_plans_on_farm_id"
    t.index ["session_id"], name: "index_cultivation_plans_on_session_id"
    t.index ["status"], name: "index_cultivation_plans_on_status"
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
    t.index ["is_reference"], name: "index_farms_on_is_reference", where: "is_reference = true"
    t.index ["user_id", "name"], name: "index_farms_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_farms_on_user_id"
    t.index ["weather_data_status"], name: "index_farms_on_weather_data_status"
    t.index ["weather_location_id"], name: "index_farms_on_weather_location_id"
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
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.float "area"
    t.float "daily_fixed_cost"
    t.index ["farm_id", "name"], name: "index_fields_on_farm_id_and_name", unique: true
    t.index ["farm_id"], name: "index_fields_on_farm_id"
    t.index ["user_id", "name"], name: "index_fields_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_fields_on_user_id"
  end

  create_table "free_crop_plans", force: :cascade do |t|
    t.integer "farm_id", null: false
    t.integer "farm_size_id", null: false
    t.integer "crop_id", null: false
    t.string "status", default: "pending", null: false
    t.string "session_id"
    t.text "plan_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crop_id"], name: "index_free_crop_plans_on_crop_id"
    t.index ["farm_id"], name: "index_free_crop_plans_on_farm_id"
    t.index ["farm_size_id"], name: "index_free_crop_plans_on_farm_size_id"
    t.index ["session_id"], name: "index_free_crop_plans_on_session_id"
    t.index ["status"], name: "index_free_crop_plans_on_status"
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

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.binary "payload", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "channel_hash", limit: 8, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id"
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id"
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id"
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", default: "default", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_availability"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_pagination"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id"
    t.index ["priority", "job_id"], name: "index_solid_queue_executions_for_dispatching"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id"
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id"
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_scheduled_executions_for_dispatching"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.boolean "admin", default: false, null: false
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
  add_foreign_key "crop_stages", "crops"
  add_foreign_key "crops", "users"
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
  add_foreign_key "free_crop_plans", "farm_sizes"
  add_foreign_key "free_crop_plans", "farms"
  add_foreign_key "sessions", "users"
  add_foreign_key "sunshine_requirements", "crop_stages"
  add_foreign_key "temperature_requirements", "crop_stages"
  add_foreign_key "thermal_requirements", "crop_stages"
  add_foreign_key "weather_data", "weather_locations"
end
