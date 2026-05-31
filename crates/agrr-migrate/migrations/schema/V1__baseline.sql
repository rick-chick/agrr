-- AGRR primary schema baseline (from development.sqlite3)
PRAGMA foreign_keys=OFF;
CREATE TABLE IF NOT EXISTS "agricultural_tasks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "description" text, "time_per_sqm" float, "weather_dependency" varchar, "required_tools" text, "skill_level" varchar, "is_reference" boolean DEFAULT 1 NOT NULL, "user_id" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "region" varchar, "source_agricultural_task_id" integer, "task_type" varchar, "task_type_id" integer);
CREATE INDEX "index_agricultural_tasks_on_is_reference" ON "agricultural_tasks" ("is_reference");
CREATE INDEX "index_agricultural_tasks_on_name" ON "agricultural_tasks" ("name") WHERE is_reference = true;
CREATE INDEX "index_agricultural_tasks_on_region" ON "agricultural_tasks" ("region");
CREATE INDEX "index_agricultural_tasks_on_task_type" ON "agricultural_tasks" ("task_type");
CREATE INDEX "index_agricultural_tasks_on_task_type_id" ON "agricultural_tasks" ("task_type_id");
CREATE UNIQUE INDEX "index_agricultural_tasks_on_user_id_and_name" ON "agricultural_tasks" ("user_id", "name") WHERE is_reference = false;
CREATE UNIQUE INDEX "idx_on_user_id_source_agricultural_task_id_87cb4ef7da" ON "agricultural_tasks" ("user_id", "source_agricultural_task_id") WHERE source_agricultural_task_id IS NOT NULL;
CREATE INDEX "index_agricultural_tasks_on_user_id" ON "agricultural_tasks" ("user_id");
CREATE TABLE IF NOT EXISTS "contact_messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "email" varchar NOT NULL, "subject" varchar, "source" varchar, "message" text NOT NULL, "status" varchar DEFAULT 'queued' NOT NULL, "sent_at" datetime, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_contact_messages_on_email" ON "contact_messages" ("email");
CREATE INDEX "index_contact_messages_on_status" ON "contact_messages" ("status");
CREATE TABLE IF NOT EXISTS "farm_sizes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "area_sqm" integer NOT NULL, "display_order" integer DEFAULT 0 NOT NULL, "active" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_farm_sizes_on_active" ON "farm_sizes" ("active");
CREATE INDEX "index_farm_sizes_on_display_order" ON "farm_sizes" ("display_order");
CREATE TABLE IF NOT EXISTS "fertilizes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "n" float, "p" float, "k" float, "description" text, "is_reference" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "package_size" float, "user_id" integer, "region" varchar, "source_fertilize_id" integer);
CREATE UNIQUE INDEX "index_fertilizes_on_name" ON "fertilizes" ("name");
CREATE INDEX "index_fertilizes_on_region" ON "fertilizes" ("region");
CREATE UNIQUE INDEX "index_fertilizes_on_user_id_and_source_fertilize_id" ON "fertilizes" ("user_id", "source_fertilize_id") WHERE source_fertilize_id IS NOT NULL;
CREATE INDEX "index_fertilizes_on_user_id" ON "fertilizes" ("user_id");
CREATE TABLE IF NOT EXISTS "solid_cache_entries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" blob(1024) NOT NULL, "value" blob(536870912) NOT NULL, "created_at" datetime(6) NOT NULL, "key_hash" integer(8) NOT NULL, "byte_size" integer(4) NOT NULL);
CREATE INDEX "index_solid_cache_entries_on_byte_size" ON "solid_cache_entries" ("byte_size");
CREATE INDEX "index_solid_cache_entries_on_key_hash_and_byte_size" ON "solid_cache_entries" ("key_hash", "byte_size");
CREATE UNIQUE INDEX "index_solid_cache_entries_on_key_hash" ON "solid_cache_entries" ("key_hash");
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email" varchar, "name" varchar, "google_id" varchar, "avatar_url" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "admin" boolean, "is_anonymous" boolean DEFAULT 0 NOT NULL, "api_key" varchar);
CREATE UNIQUE INDEX "index_users_on_api_key" ON "users" ("api_key") WHERE api_key IS NOT NULL;
CREATE UNIQUE INDEX "index_users_on_email" ON "users" ("email") WHERE is_anonymous = false;
CREATE UNIQUE INDEX "index_users_on_google_id" ON "users" ("google_id") WHERE is_anonymous = false;
CREATE TABLE IF NOT EXISTS "weather_locations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "latitude" decimal, "longitude" decimal, "elevation" decimal, "timezone" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "predicted_weather_data" text);
CREATE TABLE IF NOT EXISTS "crop_pests" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_id" integer NOT NULL, "pest_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d752eff920"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
, CONSTRAINT "fk_rails_8f26d81285"
FOREIGN KEY ("pest_id")
  REFERENCES "pests" ("id")
);
CREATE UNIQUE INDEX "index_crop_pests_on_crop_id_and_pest_id" ON "crop_pests" ("crop_id", "pest_id");
CREATE INDEX "index_crop_pests_on_crop_id" ON "crop_pests" ("crop_id");
CREATE INDEX "index_crop_pests_on_pest_id" ON "crop_pests" ("pest_id");
CREATE TABLE IF NOT EXISTS "crop_stages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_id" integer NOT NULL, "name" varchar NOT NULL, "order" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_00e01226b6"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
);
CREATE UNIQUE INDEX "index_crop_stages_on_crop_id_and_order" ON "crop_stages" ("crop_id", "order");
CREATE INDEX "index_crop_stages_on_crop_id" ON "crop_stages" ("crop_id");
CREATE TABLE IF NOT EXISTS "crop_task_schedule_blueprints" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_id" integer NOT NULL, "agricultural_task_id" integer, "stage_order" integer NOT NULL, "stage_name" varchar, "gdd_trigger" decimal(10,2) NOT NULL, "gdd_tolerance" decimal(10,2), "task_type" varchar NOT NULL, "source" varchar NOT NULL, "priority" integer NOT NULL, "amount" decimal(10,3), "amount_unit" varchar, "description" text, "weather_dependency" varchar, "time_per_sqm" decimal(8,2), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "name" varchar, "source_agricultural_task_id" bigint, CONSTRAINT "fk_rails_d19b83189c"
FOREIGN KEY ("agricultural_task_id")
  REFERENCES "agricultural_tasks" ("id")
, CONSTRAINT "fk_rails_e7489a1e4e"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
);
CREATE INDEX "index_crop_task_schedule_blueprints_on_agricultural_task_id" ON "crop_task_schedule_blueprints" ("agricultural_task_id");
CREATE UNIQUE INDEX "idx_on_crop_id_stage_order_agricultural_task_id_1de52a2f7e" ON "crop_task_schedule_blueprints" ("crop_id", "stage_order", "agricultural_task_id") WHERE agricultural_task_id IS NOT NULL;
CREATE UNIQUE INDEX "index_blueprints_on_crop_stage_and_source_task" ON "crop_task_schedule_blueprints" ("crop_id", "stage_order", "source_agricultural_task_id") WHERE agricultural_task_id IS NULL AND source_agricultural_task_id IS NOT NULL;
CREATE INDEX "index_crop_task_schedule_blueprints_on_crop_id" ON "crop_task_schedule_blueprints" ("crop_id");
CREATE TABLE IF NOT EXISTS "crop_task_templates" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_id" integer NOT NULL, "source_agricultural_task_id" bigint, "name" varchar NOT NULL, "description" text, "time_per_sqm" float, "weather_dependency" varchar, "required_tools" text, "skill_level" varchar, "task_type" varchar, "task_type_id" integer, "is_reference" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "agricultural_task_id" integer, "ai_state" varchar DEFAULT 'pending' NOT NULL, "ai_last_synced_at" datetime(6), "ai_failure_reason" text, CONSTRAINT "fk_rails_23e81e7508"
FOREIGN KEY ("agricultural_task_id")
  REFERENCES "agricultural_tasks" ("id")
, CONSTRAINT "fk_rails_93e038aa90"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
);
CREATE INDEX "index_crop_task_templates_on_agricultural_task_id" ON "crop_task_templates" ("agricultural_task_id");
CREATE INDEX "index_crop_task_templates_on_ai_state" ON "crop_task_templates" ("ai_state");
CREATE UNIQUE INDEX "idx_crop_task_templates_on_crop_and_agricultural_task" ON "crop_task_templates" ("crop_id", "agricultural_task_id");
CREATE UNIQUE INDEX "index_crop_task_templates_on_crop_id_and_name" ON "crop_task_templates" ("crop_id", "name");
CREATE UNIQUE INDEX "idx_crop_task_templates_on_crop_and_source" ON "crop_task_templates" ("crop_id", "source_agricultural_task_id");
CREATE INDEX "index_crop_task_templates_on_crop_id" ON "crop_task_templates" ("crop_id");
CREATE TABLE IF NOT EXISTS "crops" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer, "name" varchar NOT NULL, "variety" varchar, "is_reference" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "area_per_unit" float, "revenue_per_area" float, "groups" text, "region" varchar, "source_crop_id" integer, CONSTRAINT "fk_rails_adf9cfe4f1"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_crops_on_region" ON "crops" ("region");
CREATE UNIQUE INDEX "index_crops_on_user_id_and_source_crop_id" ON "crops" ("user_id", "source_crop_id") WHERE source_crop_id IS NOT NULL;
CREATE INDEX "index_crops_on_user_id" ON "crops" ("user_id");
CREATE TABLE IF NOT EXISTS "cultivation_plan_crops" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "cultivation_plan_id" integer NOT NULL, "name" varchar NOT NULL, "variety" varchar, "area_per_unit" float, "revenue_per_area" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "crop_id" integer, CONSTRAINT "fk_rails_ccf0bf58e2"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
, CONSTRAINT "fk_rails_cef938b6ab"
FOREIGN KEY ("cultivation_plan_id")
  REFERENCES "cultivation_plans" ("id")
);
CREATE INDEX "index_cultivation_plan_crops_on_crop_id" ON "cultivation_plan_crops" ("crop_id");
CREATE INDEX "index_cultivation_plan_crops_on_cultivation_plan_id" ON "cultivation_plan_crops" ("cultivation_plan_id");
CREATE TABLE IF NOT EXISTS "cultivation_plan_fields" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "cultivation_plan_id" integer NOT NULL, "name" varchar NOT NULL, "area" float NOT NULL, "daily_fixed_cost" float, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_52b008fe45"
FOREIGN KEY ("cultivation_plan_id")
  REFERENCES "cultivation_plans" ("id")
);
CREATE INDEX "index_cultivation_plan_fields_on_cultivation_plan_id" ON "cultivation_plan_fields" ("cultivation_plan_id");
CREATE TABLE IF NOT EXISTS "cultivation_plans" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "farm_id" integer NOT NULL, "user_id" integer, "session_id" varchar, "total_area" float NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "error_message" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "optimization_phase" varchar, "optimization_phase_message" text, "planning_start_date" date, "planning_end_date" date, "total_profit" decimal, "total_revenue" decimal, "total_cost" decimal, "optimization_time" decimal, "algorithm_used" varchar, "is_optimal" boolean, "optimization_summary" text, "predicted_weather_data" text, "plan_type" varchar DEFAULT 'public' NOT NULL, "plan_name" varchar, "plan_year" integer, CONSTRAINT "fk_rails_cf3724e55f"
FOREIGN KEY ("farm_id")
  REFERENCES "farms" ("id")
, CONSTRAINT "fk_rails_622ccef362"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE UNIQUE INDEX "index_cultivation_plans_on_farm_user_unique" ON "cultivation_plans" ("farm_id", "user_id") WHERE plan_type = 'private';
CREATE INDEX "index_cultivation_plans_on_farm_id" ON "cultivation_plans" ("farm_id");
CREATE INDEX "index_cultivation_plans_on_plan_type" ON "cultivation_plans" ("plan_type");
CREATE INDEX "index_cultivation_plans_on_session_id" ON "cultivation_plans" ("session_id");
CREATE INDEX "index_cultivation_plans_on_status" ON "cultivation_plans" ("status");
CREATE INDEX "index_cultivation_plans_on_user_plan_name_year" ON "cultivation_plans" ("user_id", "plan_name", "plan_year") WHERE plan_type = 'private';
CREATE INDEX "index_cultivation_plans_on_user_id_and_plan_year" ON "cultivation_plans" ("user_id", "plan_year") WHERE plan_type = 'private';
CREATE INDEX "index_cultivation_plans_on_user_id" ON "cultivation_plans" ("user_id");
CREATE TABLE IF NOT EXISTS "deletion_undo_events" ("id" varchar NOT NULL PRIMARY KEY, "resource_type" varchar NOT NULL, "resource_id" varchar NOT NULL, "snapshot" json DEFAULT '{}' NOT NULL, "metadata" json DEFAULT '{}' NOT NULL, "deleted_by_id" integer, "expires_at" datetime(6) NOT NULL, "state" varchar DEFAULT 'scheduled' NOT NULL, "restored_at" datetime(6), "finalized_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d22a7ad234"
FOREIGN KEY ("deleted_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_deletion_undo_events_on_deleted_by_id" ON "deletion_undo_events" ("deleted_by_id");
CREATE INDEX "index_deletion_undo_events_on_expires_at" ON "deletion_undo_events" ("expires_at");
CREATE INDEX "index_deletion_undo_events_on_resource" ON "deletion_undo_events" ("resource_type", "resource_id") WHERE state = 'scheduled';
CREATE TABLE IF NOT EXISTS "farms" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "name" varchar NOT NULL, "latitude" decimal(10,8), "longitude" decimal(11,8), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "weather_data_status" varchar DEFAULT 'pending' NOT NULL, "weather_data_fetched_years" integer DEFAULT 0 NOT NULL, "weather_data_total_years" integer DEFAULT 0 NOT NULL, "weather_data_last_error" text, "last_broadcast_at" datetime(6), "weather_location_id" integer, "is_reference" boolean DEFAULT 0 NOT NULL, "region" varchar, "predicted_weather_data" text, "source_farm_id" integer, CONSTRAINT "fk_rails_2a5f4d1971"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_5851fbe050"
FOREIGN KEY ("weather_location_id")
  REFERENCES "weather_locations" ("id")
);
CREATE INDEX "index_farms_on_is_reference" ON "farms" ("is_reference") WHERE is_reference = true;
CREATE INDEX "index_farms_on_region" ON "farms" ("region");
CREATE UNIQUE INDEX "index_farms_on_user_id_and_name" ON "farms" ("user_id", "name");
CREATE UNIQUE INDEX "index_farms_on_user_id_and_source_farm_id" ON "farms" ("user_id", "source_farm_id") WHERE source_farm_id IS NOT NULL;
CREATE INDEX "index_farms_on_user_id" ON "farms" ("user_id");
CREATE INDEX "index_farms_on_weather_data_status" ON "farms" ("weather_data_status");
CREATE INDEX "index_farms_on_weather_location_id" ON "farms" ("weather_location_id");
CREATE TABLE IF NOT EXISTS "field_cultivations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "cultivation_plan_id" integer NOT NULL, "area" float NOT NULL, "start_date" date, "completion_date" date, "cultivation_days" integer, "estimated_cost" float, "status" varchar DEFAULT 'pending' NOT NULL, "optimization_result" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "cultivation_plan_field_id" integer, "cultivation_plan_crop_id" integer, CONSTRAINT "fk_rails_4ac78dfa36"
FOREIGN KEY ("cultivation_plan_field_id")
  REFERENCES "cultivation_plan_fields" ("id")
, CONSTRAINT "fk_rails_d38d257fad"
FOREIGN KEY ("cultivation_plan_crop_id")
  REFERENCES "cultivation_plan_crops" ("id")
, CONSTRAINT "fk_rails_cfab41636e"
FOREIGN KEY ("cultivation_plan_id")
  REFERENCES "cultivation_plans" ("id")
);
CREATE INDEX "index_field_cultivations_on_cultivation_plan_crop_id" ON "field_cultivations" ("cultivation_plan_crop_id");
CREATE INDEX "index_field_cultivations_on_cultivation_plan_field_id" ON "field_cultivations" ("cultivation_plan_field_id");
CREATE INDEX "index_field_cultivations_on_cultivation_plan_id" ON "field_cultivations" ("cultivation_plan_id");
CREATE INDEX "index_field_cultivations_on_cultivation_plan_id_and_field_id" ON "field_cultivations" ("cultivation_plan_id");
CREATE INDEX "index_field_cultivations_on_status" ON "field_cultivations" ("status");
CREATE TABLE IF NOT EXISTS "fields" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "farm_id" integer NOT NULL, "user_id" integer, "name" varchar NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "area" float, "daily_fixed_cost" float, "region" varchar, CONSTRAINT "fk_rails_d7113af70e"
FOREIGN KEY ("farm_id")
  REFERENCES "farms" ("id")
, CONSTRAINT "fk_rails_b061b4e224"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_fields_on_farm_id_and_name" ON "fields" ("farm_id", "name");
CREATE INDEX "index_fields_on_farm_id" ON "fields" ("farm_id");
CREATE INDEX "index_fields_on_region" ON "fields" ("region");
CREATE UNIQUE INDEX "index_fields_on_user_id_and_farm_id_and_name" ON "fields" ("user_id", "farm_id", "name");
CREATE INDEX "index_fields_on_user_id" ON "fields" ("user_id");
CREATE TABLE IF NOT EXISTS "free_crop_plans" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "farm_id" integer NOT NULL, "crop_id" integer NOT NULL, "session_id" varchar, "area_sqm" integer NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "plan_data" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9cefcb17ea"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
, CONSTRAINT "fk_rails_a47cf36095"
FOREIGN KEY ("farm_id")
  REFERENCES "farms" ("id")
);
CREATE INDEX "index_free_crop_plans_on_crop_id" ON "free_crop_plans" ("crop_id");
CREATE INDEX "index_free_crop_plans_on_farm_id" ON "free_crop_plans" ("farm_id");
CREATE INDEX "index_free_crop_plans_on_session_id" ON "free_crop_plans" ("session_id");
CREATE INDEX "index_free_crop_plans_on_status" ON "free_crop_plans" ("status");
CREATE TABLE IF NOT EXISTS "interaction_rules" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "rule_type" varchar NOT NULL, "source_group" varchar NOT NULL, "target_group" varchar NOT NULL, "impact_ratio" decimal(5,2) NOT NULL, "is_directional" boolean DEFAULT 1 NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "user_id" integer, "is_reference" boolean DEFAULT 0 NOT NULL, "region" varchar, "source_interaction_rule_id" integer, CONSTRAINT "fk_rails_ee2502f0c6"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_interaction_rules_on_is_reference" ON "interaction_rules" ("is_reference");
CREATE INDEX "index_interaction_rules_on_region" ON "interaction_rules" ("region");
CREATE INDEX "index_interaction_rules_on_type_and_groups" ON "interaction_rules" ("rule_type", "source_group", "target_group");
CREATE INDEX "index_interaction_rules_on_rule_type" ON "interaction_rules" ("rule_type");
CREATE INDEX "index_interaction_rules_on_source_group" ON "interaction_rules" ("source_group");
CREATE INDEX "index_interaction_rules_on_target_group" ON "interaction_rules" ("target_group");
CREATE INDEX "index_interaction_rules_on_user_id_and_is_reference" ON "interaction_rules" ("user_id", "is_reference");
CREATE UNIQUE INDEX "idx_on_user_id_source_interaction_rule_id_0cbec4be31" ON "interaction_rules" ("user_id", "source_interaction_rule_id") WHERE source_interaction_rule_id IS NOT NULL;
CREATE INDEX "index_interaction_rules_on_user_id" ON "interaction_rules" ("user_id");
CREATE TABLE IF NOT EXISTS "nutrient_requirements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_stage_id" integer NOT NULL, "daily_uptake_n" float, "daily_uptake_p" float, "daily_uptake_k" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "region" varchar, "is_reference" boolean DEFAULT 1 NOT NULL, CONSTRAINT "fk_rails_c2d675f5b7"
FOREIGN KEY ("crop_stage_id")
  REFERENCES "crop_stages" ("id")
);
CREATE INDEX "index_nutrient_requirements_on_crop_stage_id" ON "nutrient_requirements" ("crop_stage_id");
CREATE INDEX "index_nutrient_requirements_on_is_reference" ON "nutrient_requirements" ("is_reference");
CREATE INDEX "index_nutrient_requirements_on_region" ON "nutrient_requirements" ("region");
CREATE TABLE IF NOT EXISTS "pest_control_methods" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "pest_id" integer NOT NULL, "method_type" varchar NOT NULL, "method_name" varchar NOT NULL, "description" text, "timing_hint" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_df9b2e1bad"
FOREIGN KEY ("pest_id")
  REFERENCES "pests" ("id")
);
CREATE INDEX "index_pest_control_methods_on_method_type" ON "pest_control_methods" ("method_type");
CREATE INDEX "index_pest_control_methods_on_pest_id" ON "pest_control_methods" ("pest_id");
CREATE TABLE IF NOT EXISTS "pest_temperature_profiles" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "pest_id" integer NOT NULL, "base_temperature" float, "max_temperature" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_cb97ef439b"
FOREIGN KEY ("pest_id")
  REFERENCES "pests" ("id")
);
CREATE INDEX "index_pest_temperature_profiles_on_pest_id" ON "pest_temperature_profiles" ("pest_id");
CREATE TABLE IF NOT EXISTS "pest_thermal_requirements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "pest_id" integer NOT NULL, "required_gdd" float, "first_generation_gdd" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1986245061"
FOREIGN KEY ("pest_id")
  REFERENCES "pests" ("id")
);
CREATE INDEX "index_pest_thermal_requirements_on_pest_id" ON "pest_thermal_requirements" ("pest_id");
CREATE TABLE IF NOT EXISTS "pesticide_application_details" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "pesticide_id" integer NOT NULL, "dilution_ratio" varchar, "amount_per_m2" float, "amount_unit" varchar, "application_method" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c75a6c8f89"
FOREIGN KEY ("pesticide_id")
  REFERENCES "pesticides" ("id")
);
CREATE INDEX "index_pesticide_application_details_on_pesticide_id" ON "pesticide_application_details" ("pesticide_id");
CREATE TABLE IF NOT EXISTS "pesticide_usage_constraints" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "pesticide_id" integer NOT NULL, "min_temperature" float, "max_temperature" float, "max_wind_speed_m_s" float, "max_application_count" integer, "harvest_interval_days" integer, "other_constraints" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_0c33beafa3"
FOREIGN KEY ("pesticide_id")
  REFERENCES "pesticides" ("id")
);
CREATE INDEX "index_pesticide_usage_constraints_on_pesticide_id" ON "pesticide_usage_constraints" ("pesticide_id");
CREATE TABLE IF NOT EXISTS "pesticides" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "active_ingredient" varchar, "description" text, "is_reference" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "crop_id" integer NOT NULL, "pest_id" integer NOT NULL, "user_id" integer, "region" varchar, "source_pesticide_id" integer, CONSTRAINT "fk_rails_ddbe926186"
FOREIGN KEY ("pest_id")
  REFERENCES "pests" ("id")
, CONSTRAINT "fk_rails_0317a51632"
FOREIGN KEY ("crop_id")
  REFERENCES "crops" ("id")
, CONSTRAINT "fk_rails_161229aff2"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_pesticides_on_crop_id" ON "pesticides" ("crop_id");
CREATE INDEX "index_pesticides_on_is_reference" ON "pesticides" ("is_reference");
CREATE INDEX "index_pesticides_on_pest_id" ON "pesticides" ("pest_id");
CREATE INDEX "index_pesticides_on_region" ON "pesticides" ("region");
CREATE UNIQUE INDEX "index_pesticides_on_user_id_and_source_pesticide_id" ON "pesticides" ("user_id", "source_pesticide_id") WHERE source_pesticide_id IS NOT NULL;
CREATE INDEX "index_pesticides_on_user_id" ON "pesticides" ("user_id");
CREATE TABLE IF NOT EXISTS "pests" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "name_scientific" varchar, "family" varchar, "order" varchar, "description" text, "occurrence_season" varchar, "is_reference" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "user_id" integer, "region" varchar, "source_pest_id" integer, CONSTRAINT "fk_rails_1dae73ea2d"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_pests_on_is_reference" ON "pests" ("is_reference");
CREATE INDEX "index_pests_on_region" ON "pests" ("region");
CREATE UNIQUE INDEX "index_pests_on_user_id_and_source_pest_id" ON "pests" ("user_id", "source_pest_id") WHERE source_pest_id IS NOT NULL;
CREATE INDEX "index_pests_on_user_id" ON "pests" ("user_id");
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" varchar NOT NULL, "data" text, "user_id" integer NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_expires_at" ON "sessions" ("expires_at");
CREATE UNIQUE INDEX "index_sessions_on_session_id" ON "sessions" ("session_id");
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id");
CREATE TABLE IF NOT EXISTS "sunshine_requirements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_stage_id" integer NOT NULL, "minimum_sunshine_hours" float, "target_sunshine_hours" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_f386cada0e"
FOREIGN KEY ("crop_stage_id")
  REFERENCES "crop_stages" ("id")
);
CREATE INDEX "index_sunshine_requirements_on_crop_stage_id" ON "sunshine_requirements" ("crop_stage_id");
CREATE TABLE IF NOT EXISTS "task_schedule_items" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "task_schedule_id" integer NOT NULL, "task_type" varchar NOT NULL, "name" varchar NOT NULL, "description" text, "stage_name" varchar, "stage_order" integer, "gdd_trigger" decimal(10,2), "gdd_tolerance" decimal(10,2), "scheduled_date" date, "priority" integer, "source" varchar NOT NULL, "weather_dependency" varchar, "time_per_sqm" decimal(8,2), "amount" decimal(10,3), "amount_unit" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "agricultural_task_id" integer, "source_agricultural_task_id" bigint, "status" varchar DEFAULT 'planned' NOT NULL, "actual_date" date, "actual_notes" text, "rescheduled_at" datetime(6), "cancelled_at" datetime(6), "completed_at" datetime(6), CONSTRAINT "fk_rails_428434dba0"
FOREIGN KEY ("agricultural_task_id")
  REFERENCES "agricultural_tasks" ("id")
, CONSTRAINT "fk_rails_7c82bfd3b4"
FOREIGN KEY ("task_schedule_id")
  REFERENCES "task_schedules" ("id")
);
CREATE INDEX "index_task_schedule_items_on_agricultural_task_id" ON "task_schedule_items" ("agricultural_task_id");
CREATE INDEX "index_task_schedule_items_on_scheduled_date" ON "task_schedule_items" ("scheduled_date");
CREATE INDEX "index_task_schedule_items_on_source_agricultural_task_id" ON "task_schedule_items" ("source_agricultural_task_id");
CREATE INDEX "index_task_schedule_items_on_status" ON "task_schedule_items" ("status");
CREATE INDEX "index_task_schedule_items_on_schedule_and_date" ON "task_schedule_items" ("task_schedule_id", "scheduled_date");
CREATE INDEX "index_task_schedule_items_on_task_schedule_id" ON "task_schedule_items" ("task_schedule_id");
CREATE TABLE IF NOT EXISTS "task_schedules" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "cultivation_plan_id" integer NOT NULL, "field_cultivation_id" integer, "category" varchar NOT NULL, "status" varchar DEFAULT 'active' NOT NULL, "source" varchar DEFAULT 'agrr' NOT NULL, "generated_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_0c36f7ad62"
FOREIGN KEY ("cultivation_plan_id")
  REFERENCES "cultivation_plans" ("id")
, CONSTRAINT "fk_rails_b7a8c04c43"
FOREIGN KEY ("field_cultivation_id")
  REFERENCES "field_cultivations" ("id")
);
CREATE UNIQUE INDEX "index_task_schedules_unique_scope" ON "task_schedules" ("cultivation_plan_id", "field_cultivation_id", "category");
CREATE INDEX "index_task_schedules_on_cultivation_plan_id" ON "task_schedules" ("cultivation_plan_id");
CREATE INDEX "index_task_schedules_on_field_cultivation_id" ON "task_schedules" ("field_cultivation_id");
CREATE TABLE IF NOT EXISTS "temperature_requirements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_stage_id" integer NOT NULL, "base_temperature" float, "optimal_min" float, "optimal_max" float, "low_stress_threshold" float, "high_stress_threshold" float, "frost_threshold" float, "sterility_risk_threshold" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "max_temperature" float, CONSTRAINT "fk_rails_3a38debfb8"
FOREIGN KEY ("crop_stage_id")
  REFERENCES "crop_stages" ("id")
);
CREATE INDEX "index_temperature_requirements_on_crop_stage_id" ON "temperature_requirements" ("crop_stage_id");
CREATE TABLE IF NOT EXISTS "thermal_requirements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "crop_stage_id" integer NOT NULL, "required_gdd" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_debdc2861a"
FOREIGN KEY ("crop_stage_id")
  REFERENCES "crop_stages" ("id")
);
CREATE INDEX "index_thermal_requirements_on_crop_stage_id" ON "thermal_requirements" ("crop_stage_id");
CREATE TABLE IF NOT EXISTS "weather_data" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "weather_location_id" integer NOT NULL, "date" date, "temperature_max" decimal, "temperature_min" decimal, "temperature_mean" decimal, "precipitation" decimal, "sunshine_hours" decimal, "wind_speed" decimal, "weather_code" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "is_predicted" boolean, CONSTRAINT "fk_rails_0b848c6e7e"
FOREIGN KEY ("weather_location_id")
  REFERENCES "weather_locations" ("id")
);
CREATE UNIQUE INDEX "index_weather_data_on_location_and_date" ON "weather_data" ("weather_location_id", "date");
CREATE INDEX "index_weather_data_on_weather_location_id" ON "weather_data" ("weather_location_id");
PRAGMA foreign_keys=ON;
