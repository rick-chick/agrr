//! Minimal SQLite schema + seed for `PlanSaveSession` integration tests.
//!
//! Rails parity map:
//! - `seed_plan_reuse` ↔ `test/integration/cultivation_plan/public_plan_save_test.rb`
//!   — `"reuses existing private plan when same public plan is saved twice"`
//! - `seed_task_schedule_copy` ↔ same file — `"copies task schedules and items from reference plan"`
//! - `seed_crop_stage_requirements_copy` ↔ same file — `"copies nutrient requirements for each crop stage"` (thermal/temperature parity)

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    PublicPlanSaveFieldDatum, PublicPlanSaveSessionData, PublicPlanSaveWorkspace,
};
use rusqlite::params;

pub const TEST_USER_ID: i64 = 42;

pub struct PlanReuseSeed {
    pub workspace: PublicPlanSaveWorkspace,
}

pub struct TaskScheduleCopySeed {
    pub workspace: PublicPlanSaveWorkspace,
    pub reference_agricultural_task_id: i64,
}

pub struct CropStageRequirementsCopySeed {
    pub workspace: PublicPlanSaveWorkspace,
    pub reference_crop_id: i64,
    pub reference_stage_name: &'static str,
}

pub fn plan_save_integration_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_plan_save_it_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "plan_save_it_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| conn.execute_batch(PLAN_SAVE_INTEGRATION_DDL))
        .unwrap();
    pool
}

const PLAN_SAVE_INTEGRATION_DDL: &str = "
CREATE TABLE farms (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT,
  latitude REAL,
  longitude REAL,
  region TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
  weather_location_id INTEGER,
  source_farm_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE fields (
  id INTEGER PRIMARY KEY,
  farm_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  area REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE crops (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  variety TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
  area_per_unit REAL,
  revenue_per_area REAL,
  region TEXT,
  groups TEXT,
  source_crop_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE agricultural_tasks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  description TEXT,
  time_per_sqm REAL,
  weather_dependency TEXT,
  required_tools TEXT,
  skill_level TEXT,
  region TEXT,
  task_type TEXT,
  task_type_id INTEGER,
  is_reference INTEGER NOT NULL DEFAULT 0,
  source_agricultural_task_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE crop_stages (
  id INTEGER PRIMARY KEY,
  crop_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  \"order\" INTEGER NOT NULL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE temperature_requirements (
  id INTEGER PRIMARY KEY,
  crop_stage_id INTEGER NOT NULL,
  base_temperature REAL,
  optimal_min REAL,
  optimal_max REAL,
  low_stress_threshold REAL,
  high_stress_threshold REAL,
  frost_threshold REAL,
  sterility_risk_threshold REAL,
  max_temperature REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE thermal_requirements (
  id INTEGER PRIMARY KEY,
  crop_stage_id INTEGER NOT NULL,
  required_gdd REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE sunshine_requirements (
  id INTEGER PRIMARY KEY,
  crop_stage_id INTEGER NOT NULL,
  minimum_sunshine_hours REAL,
  target_sunshine_hours REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE nutrient_requirements (
  id INTEGER PRIMARY KEY,
  crop_stage_id INTEGER NOT NULL,
  daily_uptake_n REAL,
  daily_uptake_p REAL,
  daily_uptake_k REAL,
  region TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE crop_task_templates (
  id INTEGER PRIMARY KEY,
  crop_id INTEGER NOT NULL,
  agricultural_task_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  time_per_sqm REAL,
  weather_dependency TEXT,
  required_tools TEXT,
  skill_level TEXT,
  task_type TEXT,
  task_type_id INTEGER,
  is_reference INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE cultivation_plans (
  id INTEGER PRIMARY KEY,
  farm_id INTEGER NOT NULL,
  user_id INTEGER,
  total_area REAL,
  plan_type TEXT,
  plan_year INTEGER,
  plan_name TEXT,
  planning_start_date TEXT,
  planning_end_date TEXT,
  status TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE predicted_weather_metadata (
  scope TEXT NOT NULL,
  scope_id INTEGER NOT NULL,
  prediction_start_date TEXT NOT NULL,
  prediction_end_date TEXT NOT NULL,
  target_end_date TEXT NOT NULL,
  data_end_date TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  PRIMARY KEY (scope, scope_id)
);
CREATE TABLE cultivation_plan_fields (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  area REAL,
  daily_fixed_cost REAL,
  description TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE cultivation_plan_crops (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  crop_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  variety TEXT,
  area_per_unit REAL,
  revenue_per_area REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE field_cultivations (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  cultivation_plan_field_id INTEGER NOT NULL,
  cultivation_plan_crop_id INTEGER NOT NULL,
  area REAL,
  start_date TEXT,
  completion_date TEXT,
  cultivation_days INTEGER,
  estimated_cost REAL,
  status TEXT,
  optimization_result TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE task_schedules (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  field_cultivation_id INTEGER NOT NULL,
  category TEXT,
  status TEXT,
  source TEXT,
  generated_at TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE task_schedule_items (
  id INTEGER PRIMARY KEY,
  task_schedule_id INTEGER NOT NULL,
  task_type TEXT NOT NULL,
  name TEXT NOT NULL,
  stage_name TEXT,
  stage_order INTEGER,
  gdd_trigger REAL,
  gdd_tolerance REAL,
  scheduled_date TEXT,
  priority INTEGER,
  source TEXT,
  weather_dependency TEXT,
  time_per_sqm REAL,
  amount REAL,
  amount_unit TEXT,
  status TEXT,
  rescheduled_at TEXT,
  cancelled_at TEXT,
  agricultural_task_id INTEGER,
  source_agricultural_task_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE crop_task_schedule_blueprints (
  id INTEGER PRIMARY KEY,
  crop_id INTEGER NOT NULL,
  agricultural_task_id INTEGER,
  source_agricultural_task_id INTEGER,
  stage_order INTEGER,
  stage_name TEXT,
  gdd_trigger REAL,
  gdd_tolerance REAL,
  task_type TEXT,
  source TEXT,
  priority INTEGER,
  amount REAL,
  amount_unit TEXT,
  description TEXT,
  weather_dependency TEXT,
  time_per_sqm REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pests (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  name_scientific TEXT,
  family TEXT,
  \"order\" TEXT,
  description TEXT,
  occurrence_season TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
  region TEXT,
  source_pest_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pest_temperature_profiles (
  id INTEGER PRIMARY KEY,
  pest_id INTEGER NOT NULL,
  base_temperature REAL,
  max_temperature REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pest_thermal_requirements (
  id INTEGER PRIMARY KEY,
  pest_id INTEGER NOT NULL,
  required_gdd REAL,
  first_generation_gdd REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pest_control_methods (
  id INTEGER PRIMARY KEY,
  pest_id INTEGER NOT NULL,
  method_type TEXT NOT NULL,
  method_name TEXT NOT NULL,
  description TEXT,
  timing_hint TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE crop_pests (
  id INTEGER PRIMARY KEY,
  crop_id INTEGER NOT NULL,
  pest_id INTEGER NOT NULL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE fertilizes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  n REAL,
  p REAL,
  k REAL,
  description TEXT,
  package_size REAL,
  is_reference INTEGER NOT NULL DEFAULT 1,
  region TEXT,
  source_fertilize_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pesticides (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  crop_id INTEGER NOT NULL,
  pest_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  active_ingredient TEXT,
  description TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
  region TEXT,
  source_pesticide_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pesticide_usage_constraints (
  id INTEGER PRIMARY KEY,
  pesticide_id INTEGER NOT NULL,
  min_temperature REAL,
  max_temperature REAL,
  max_wind_speed_m_s REAL,
  max_application_count INTEGER,
  harvest_interval_days INTEGER,
  other_constraints TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE pesticide_application_details (
  id INTEGER PRIMARY KEY,
  pesticide_id INTEGER NOT NULL,
  dilution_ratio TEXT,
  amount_per_m2 REAL,
  amount_unit TEXT,
  application_method TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE interaction_rules (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  rule_type TEXT NOT NULL,
  source_group TEXT NOT NULL,
  target_group TEXT NOT NULL,
  impact_ratio REAL NOT NULL,
  is_directional INTEGER NOT NULL DEFAULT 1,
  description TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
  region TEXT,
  source_interaction_rule_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
";

/// Parity: `reuses existing private plan when same public plan is saved twice`
pub fn seed_plan_reuse(pool: &SqlitePool) -> PlanReuseSeed {
    let reference_farm_id = 1_i64;
    let public_plan_id = 10_i64;
    let reference_crop_id = 100_i64;
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (?1, NULL, '参照農場', 35.0, 139.0, 'jp', 1, datetime('now'), datetime('now'))",
            params![reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at)
             VALUES (?1, NULL, '参照作物', 'V1', 1, 1.0, 2000.0, 'jp', '[]', datetime('now'), datetime('now'))",
            params![reference_crop_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, NULL, 100.0, 'public', 2026, 'Plan再利用テスト計画', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![public_plan_id, reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at)
             VALUES (200, ?1, ?2, '参照作物', 'V1', 1.0, 2000.0, datetime('now'), datetime('now'))",
            params![public_plan_id, reference_crop_id],
        )?;
        Ok(())
    })
    .unwrap();

    let session = PublicPlanSaveSessionData::new(
        public_plan_id,
        Some(reference_farm_id),
        vec![PublicPlanSaveFieldDatum::new(
            Some("再利用圃場"),
            Some(100.0),
            vec![],
        )],
        None,
    );
    PlanReuseSeed {
        workspace: PublicPlanSaveWorkspace {
            user_id: TEST_USER_ID,
            session_data: session,
        },
    }
}

/// Parity: `copies task schedules and items from reference plan`
pub fn seed_task_schedule_copy(pool: &SqlitePool) -> TaskScheduleCopySeed {
    let reference_farm_id = 2_i64;
    let public_plan_id = 20_i64;
    let reference_crop_id = 101_i64;
    let reference_task_id = 50_i64;
    let plan_field_id = 300_i64;
    let plan_crop_id = 301_i64;
    let field_cultivation_id = 400_i64;
    let task_schedule_id = 500_i64;

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (?1, NULL, 'Test JP Farm', 35.0, 139.0, 'jp', 1, datetime('now'), datetime('now'))",
            params![reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at)
             VALUES (?1, NULL, '参照作業作物', 'R1', 1, 1.0, 2000.0, 'jp', '[]', datetime('now'), datetime('now'))",
            params![reference_crop_id],
        )?;
        conn.execute(
            "INSERT INTO agricultural_tasks (id, user_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, region, task_type, is_reference, created_at, updated_at)
             VALUES (?1, NULL, '除草作業', '雑草を取り除く作業', 0.5, 'low', '[\"ホー\"]', 'beginner', 'jp', 'field_work', 1, datetime('now'), datetime('now'))",
            params![reference_task_id],
        )?;
        conn.execute(
            "INSERT INTO crop_task_templates (crop_id, agricultural_task_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, is_reference, created_at, updated_at)
             VALUES (?1, ?2, '除草作業', '雑草を取り除く作業', 0.5, 'low', '[\"ホー\"]', 'beginner', 1, datetime('now'), datetime('now'))",
            params![reference_crop_id, reference_task_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, NULL, 50.0, 'public', 2026, '作業コピー検証', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![public_plan_id, reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name, area, daily_fixed_cost, created_at, updated_at)
             VALUES (?1, ?2, 'F1', 50.0, 5.0, datetime('now'), datetime('now'))",
            params![plan_field_id, public_plan_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at)
             VALUES (?1, ?2, ?3, '参照作業作物', 'R1', 1.0, 2000.0, datetime('now'), datetime('now'))",
            params![plan_crop_id, public_plan_id, reference_crop_id],
        )?;
        conn.execute(
            "INSERT INTO field_cultivations (id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, area, start_date, completion_date, cultivation_days, estimated_cost, status, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, 50.0, '2026-05-30', '2026-06-04', 6, 500.0, 'completed', datetime('now'), datetime('now'))",
            params![field_cultivation_id, public_plan_id, plan_field_id, plan_crop_id],
        )?;
        conn.execute(
            "INSERT INTO task_schedules (id, cultivation_plan_id, field_cultivation_id, category, status, source, generated_at, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'general', 'active', 'reference_generator', datetime('now', '-1 day'), datetime('now'), datetime('now'))",
            params![task_schedule_id, public_plan_id, field_cultivation_id],
        )?;
        conn.execute(
            "INSERT INTO task_schedule_items (task_schedule_id, task_type, name, stage_name, stage_order, gdd_trigger, gdd_tolerance, scheduled_date, priority, source, weather_dependency, time_per_sqm, amount, amount_unit, agricultural_task_id, source_agricultural_task_id, status, created_at, updated_at)
             VALUES (?1, 'field_work', '参照作業', '初期', 1, 100.0, 10.0, '2026-06-02', 1, 'reference', 'no_rain_24h', 0.5, 2.5, 'kg', ?2, ?2, 'planned', datetime('now'), datetime('now'))",
            params![task_schedule_id, reference_task_id],
        )?;
        Ok(())
    })
    .unwrap();

    let session = PublicPlanSaveSessionData::new(
        public_plan_id,
        Some(reference_farm_id),
        vec![PublicPlanSaveFieldDatum::new(Some("F1"), Some(50.0), vec![35.0, 139.0])],
        None,
    );
    TaskScheduleCopySeed {
        workspace: PublicPlanSaveWorkspace {
            user_id: TEST_USER_ID,
            session_data: session,
        },
        reference_agricultural_task_id: reference_task_id,
    }
}

/// Parity: `copies nutrient requirements for each crop stage` (temperature/thermal on stage copy).
pub fn seed_crop_stage_requirements_copy(pool: &SqlitePool) -> CropStageRequirementsCopySeed {
    let reference_farm_id = 3_i64;
    let public_plan_id = 30_i64;
    let reference_crop_id = 102_i64;
    let reference_stage_id = 1000_i64;
    let reference_stage_name = "生育ステージ";

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (?1, NULL, '要件コピー農場', 35.0, 139.0, 'jp', 1, datetime('now'), datetime('now'))",
            params![reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at)
             VALUES (?1, NULL, '要件参照作物', 'REQ1', 1, 1.0, 2000.0, 'jp', '[]', datetime('now'), datetime('now'))",
            params![reference_crop_id],
        )?;
        conn.execute(
            "INSERT INTO crop_stages (id, crop_id, name, \"order\", created_at, updated_at)
             VALUES (?1, ?2, ?3, 1, datetime('now'), datetime('now'))",
            params![reference_stage_id, reference_crop_id, reference_stage_name],
        )?;
        conn.execute(
            "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature, created_at, updated_at)
             VALUES (?1, 10.0, 15.0, 25.0, 5.0, 30.0, 0.0, NULL, 35.0, datetime('now'), datetime('now'))",
            params![reference_stage_id],
        )?;
        conn.execute(
            "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at)
             VALUES (?1, 450.0, datetime('now'), datetime('now'))",
            params![reference_stage_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, NULL, 100.0, 'public', 2026, '要件コピー検証', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![public_plan_id, reference_farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at)
             VALUES (?1, ?2, '要件参照作物', 'REQ1', 1.0, 2000.0, datetime('now'), datetime('now'))",
            params![public_plan_id, reference_crop_id],
        )?;
        Ok(())
    })
    .unwrap();

    let session = PublicPlanSaveSessionData::new(
        public_plan_id,
        Some(reference_farm_id),
        vec![PublicPlanSaveFieldDatum::new(
            Some("要件圃場"),
            Some(100.0),
            vec![],
        )],
        None,
    );
    CropStageRequirementsCopySeed {
        workspace: PublicPlanSaveWorkspace {
            user_id: TEST_USER_ID,
            session_data: session,
        },
        reference_crop_id,
        reference_stage_name,
    }
}

pub fn count_private_plans(pool: &SqlitePool, user_id: i64) -> i64 {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM cultivation_plans WHERE plan_type = 'private' AND user_id = ?1",
            params![user_id],
            |r| r.get(0),
        )
    })
    .unwrap()
}
