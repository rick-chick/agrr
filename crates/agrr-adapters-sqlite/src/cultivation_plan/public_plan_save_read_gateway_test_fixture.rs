//! DDL + seed for `public_plan_save_read_gateway` tests.
//! Parity: `test/adapters/cultivation_plan/gateways/public_plan_save_read_active_record_gateway_test.rb`

use crate::pool::SqlitePool;
use rusqlite::params;

pub struct ReadGwSeed {
    pub plan_id: i64,
    pub ref_crop_id: i64,
}

pub fn read_gateway_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_read_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "read_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| conn.execute_batch(READ_GATEWAY_TEST_DDL))
        .unwrap();
    pool
}

const READ_GATEWAY_TEST_DDL: &str = "
CREATE TABLE farms (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT,
  latitude REAL,
  longitude REAL,
  region TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
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

/// Rails adapter test `setup` — plan + reference crop on jp farm.
pub fn seed_plan_and_crop(pool: &SqlitePool) -> ReadGwSeed {
    let farm_id = 1_i64;
    let plan_id = 10_i64;
    let ref_crop_id = 100_i64;
    let cpc_id = 200_i64;

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (?1, NULL, 'Ref', 35.0, 139.0, 'jp', 1, datetime('now'), datetime('now'))",
            params![farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, NULL, 10.0, 'public', 2026, 'ReadGwTest', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![plan_id, farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_fields (cultivation_plan_id, name, area, daily_fixed_cost, created_at, updated_at)
             VALUES (?1, 'F1', 5.0, 0.0, datetime('now'), datetime('now'))",
            params![plan_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, created_at, updated_at)
             VALUES (?1, NULL, 'ReadGwCrop', 'v', 1, 0.2, 100.0, 'jp', datetime('now'), datetime('now'))",
            params![ref_crop_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'ReadGwCrop', 'v', 0.2, 100.0, datetime('now'), datetime('now'))",
            params![cpc_id, plan_id, ref_crop_id],
        )?;
        Ok(())
    })
    .unwrap();

    ReadGwSeed {
        plan_id,
        ref_crop_id,
    }
}
