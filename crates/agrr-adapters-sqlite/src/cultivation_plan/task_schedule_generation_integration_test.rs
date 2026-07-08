//! Integration tests for task schedule generation read/write gateways.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use super::task_schedule_gateway::TaskScheduleSqliteGateway;
use super::task_schedule_generation_read_gateway::TaskScheduleGenerationReadSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use agrr_domain::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
use agrr_domain::agricultural_task::dtos::TaskScheduleReplaceItem;
use agrr_domain::agricultural_task::gateways::{
    TaskScheduleGateway, TaskScheduleGenerationReadGateway,
};
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use rusqlite::params;
use rust_decimal::Decimal;
use serde_json::json;
use std::str::FromStr;
use time::{Date, Month, OffsetDateTime};

type ScopeKey = (PredictedWeatherScope, i64);

struct FakePredictedWeatherStore {
    payloads: Arc<Mutex<HashMap<ScopeKey, serde_json::Value>>>,
}

impl FakePredictedWeatherStore {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            payloads: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    fn seed_plan(&self, plan_id: i64, payload: serde_json::Value) {
        self.payloads
            .lock()
            .expect("lock")
            .insert((PredictedWeatherScope::Plan, plan_id), payload);
    }
}

impl PredictedWeatherStoreGateway for FakePredictedWeatherStore {
    fn read_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
    ) -> Result<Option<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self
            .payloads
            .lock()
            .expect("lock")
            .get(&(scope, scope_id))
            .cloned())
    }

    fn write_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
        payload: &serde_json::Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.payloads
            .lock()
            .expect("lock")
            .insert((scope, scope_id), payload.clone());
        Ok(())
    }

    fn copy_plan_payload(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }
}

struct GenerationSeed {
    plan_id: i64,
    crop_id: i64,
    field_cultivation_id: i64,
    agricultural_task_id: i64,
}

const GENERATION_INTEGRATION_DDL: &str = "
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
CREATE TABLE agricultural_tasks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  description TEXT,
  time_per_sqm REAL,
  weather_dependency TEXT,
  is_reference INTEGER NOT NULL DEFAULT 0,
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
CREATE TABLE crop_task_schedule_blueprints (
  id INTEGER PRIMARY KEY,
  crop_id INTEGER NOT NULL,
  agricultural_task_id INTEGER,
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
CREATE TABLE farms (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT,
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
  name TEXT,
  area REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE cultivation_plan_crops (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  crop_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  variety TEXT,
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
  status TEXT,
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
  description TEXT,
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
  agricultural_task_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE UNIQUE INDEX index_task_schedules_unique_scope
  ON task_schedules (cultivation_plan_id, field_cultivation_id, category);
";

fn generation_integration_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!(
        "agrr_task_schedule_gen_it_{}",
        std::process::id()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "task_schedule_gen_it_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| conn.execute_batch(GENERATION_INTEGRATION_DDL))
        .unwrap();
    pool
}

fn seed_generation_fixture(pool: &SqlitePool) -> GenerationSeed {
    let plan_id = 10_i64;
    let farm_id = 1_i64;
    let crop_id = 100_i64;
    let stage_id = 200_i64;
    let agricultural_task_id = 50_i64;
    let plan_field_id = 300_i64;
    let plan_crop_id = 301_i64;
    let field_cultivation_id = 400_i64;

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, created_at, updated_at)
             VALUES (?1, 42, 'Test Farm', datetime('now'), datetime('now'))",
            params![farm_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, groups, created_at, updated_at)
             VALUES (?1, NULL, 'トマト', 'general', 1, 0.25, 5000.0, '[]', datetime('now'), datetime('now'))",
            params![crop_id],
        )?;
        conn.execute(
            "INSERT INTO crop_stages (id, crop_id, name, \"order\", created_at, updated_at)
             VALUES (?1, ?2, '育苗', 1, datetime('now'), datetime('now'))",
            params![stage_id, crop_id],
        )?;
        conn.execute(
            "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, max_temperature, created_at, updated_at)
             VALUES (?1, 10.0, 18.0, 28.0, 35.0, datetime('now'), datetime('now'))",
            params![stage_id],
        )?;
        conn.execute(
            "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at)
             VALUES (?1, 200.0, datetime('now'), datetime('now'))",
            params![stage_id],
        )?;
        conn.execute(
            "INSERT INTO agricultural_tasks (id, user_id, name, description, time_per_sqm, weather_dependency, is_reference, created_at, updated_at)
             VALUES (?1, NULL, '土壌準備', 'soil prep', 0.1, 'low', 1, datetime('now'), datetime('now'))",
            params![agricultural_task_id],
        )?;
        conn.execute(
            "INSERT INTO crop_task_schedule_blueprints (id, crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, weather_dependency, time_per_sqm, created_at, updated_at)
             VALUES (1, ?1, ?2, 1, '土壌準備', 0.0, 5.0, 'field_work', 'agrr_schedule', 1, 'low', 0.1, datetime('now'), datetime('now'))",
            params![crop_id, agricultural_task_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, 42, 100.0, 'private', 2026, '生成テスト', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![plan_id, farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name, area, created_at, updated_at)
             VALUES (?1, ?2, 'F1', 100.0, datetime('now'), datetime('now'))",
            params![plan_field_id, plan_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, crop_id, name, variety, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'トマト', 'general', datetime('now'), datetime('now'))",
            params![plan_crop_id, plan_id, crop_id],
        )?;
        conn.execute(
            "INSERT INTO field_cultivations (id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, area, start_date, completion_date, status, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, 100.0, '2026-04-01', '2026-10-31', 'completed', datetime('now'), datetime('now'))",
            params![field_cultivation_id, plan_id, plan_field_id, plan_crop_id],
        )?;
        Ok(())
    })
    .unwrap();

    GenerationSeed {
        plan_id,
        crop_id,
        field_cultivation_id,
        agricultural_task_id,
    }
}

fn dec(s: &str) -> Decimal {
    Decimal::from_str(s).unwrap()
}

#[test]
fn read_gateway_loads_plan_field_crop_blueprint_and_agrr_requirement() {
    let pool = generation_integration_pool();
    let seed = seed_generation_fixture(&pool);
    let weather_store = FakePredictedWeatherStore::new();
    weather_store.seed_plan(
        seed.plan_id,
        json!({
            "location": { "latitude": 35.0, "longitude": 135.0 },
            "data": [
                { "time": "2026-04-01T00:00:00", "temperature_2m_mean": 12.0 }
            ]
        }),
    );
    let read_gateway = TaskScheduleGenerationReadSqliteGateway::new(
        pool.clone(),
        weather_store.clone() as Arc<dyn PredictedWeatherStoreGateway>,
    );

    let plan_row = read_gateway
        .find_plan_row(seed.plan_id)
        .expect("plan row");
    assert_eq!(plan_row.id, seed.plan_id);
    assert!(plan_row.predicted_weather_data.get("data").is_some());
    assert_eq!(
        plan_row.calculated_planning_start_date,
        Some(Date::from_calendar_date(2026, Month::January, 1).unwrap())
    );

    let field_rows = read_gateway
        .list_field_cultivation_rows(seed.plan_id)
        .expect("field rows");
    assert_eq!(field_rows.len(), 1);
    assert_eq!(field_rows[0].id, seed.field_cultivation_id);
    assert_eq!(field_rows[0].crop_id, Some(seed.crop_id));
    assert_eq!(
        field_rows[0].start_date,
        Some(Date::from_calendar_date(2026, Month::April, 1).unwrap())
    );

    let crop_row = read_gateway
        .find_crop_row(seed.crop_id)
        .expect("crop row");
    assert_eq!(crop_row.name, "トマト");

    let blueprints = read_gateway
        .list_crop_task_schedule_blueprint_rows(seed.crop_id)
        .expect("blueprints");
    assert_eq!(blueprints.len(), 1);
    assert_eq!(blueprints[0].task_type, FIELD_WORK);
    assert_eq!(blueprints[0].gdd_trigger, Some(dec("0")));
    assert_eq!(
        blueprints[0]
            .agricultural_task
            .as_ref()
            .map(|t| t.id),
        Some(seed.agricultural_task_id)
    );

    let requirement = read_gateway
        .build_crop_agrr_requirement(seed.crop_id)
        .expect("agrr requirement");
    assert_eq!(requirement["crop"]["name"], "トマト");
    assert!(requirement["stage_requirements"].as_array().is_some_and(|a| !a.is_empty()));
}

#[test]
fn write_gateway_replace_and_delete_for_field_category() {
    let pool = generation_integration_pool();
    let seed = seed_generation_fixture(&pool);
    let write_gateway = TaskScheduleSqliteGateway::new(pool.clone());

    let generated_at = OffsetDateTime::from_unix_timestamp(1_700_000_000).unwrap();
    let item = TaskScheduleReplaceItem {
        task_type: FIELD_WORK.into(),
        agricultural_task_id: Some(seed.agricultural_task_id),
        name: "土壌準備".into(),
        description: Some("soil prep".into()),
        stage_name: Some("土壌準備".into()),
        stage_order: Some(1),
        gdd_trigger: dec("0"),
        gdd_tolerance: Some(dec("5")),
        scheduled_date: Date::from_calendar_date(2026, Month::April, 5).unwrap(),
        priority: Some(1),
        source: Some("agrr_schedule".into()),
        status: PLANNED.to_string(),
        weather_dependency: Some("low".into()),
        time_per_sqm: Some(dec("0.1")),
        amount: None,
        amount_unit: None,
    };

    write_gateway
        .replace_schedule_for_field_category(
            seed.plan_id,
            seed.field_cultivation_id,
            "general",
            generated_at,
            vec![item],
        )
        .expect("replace");

    let (schedule_count, item_count, item_name): (i64, i64, String) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT \
                 (SELECT COUNT(*) FROM task_schedules WHERE cultivation_plan_id = ?1), \
                 (SELECT COUNT(*) FROM task_schedule_items tsi \
                  INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                  WHERE ts.cultivation_plan_id = ?1), \
                 (SELECT tsi.name FROM task_schedule_items tsi \
                  INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                  WHERE ts.cultivation_plan_id = ?1 LIMIT 1)",
                params![seed.plan_id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
        })
        .unwrap();
    assert_eq!(schedule_count, 1);
    assert_eq!(item_count, 1);
    assert_eq!(item_name, "土壌準備");

    write_gateway
        .replace_schedule_for_field_category(
            seed.plan_id,
            seed.field_cultivation_id,
            "general",
            generated_at,
            vec![],
        )
        .expect("replace empty");

    let item_count_after_replace: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM task_schedule_items tsi \
                 INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                 WHERE ts.cultivation_plan_id = ?1",
                params![seed.plan_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(item_count_after_replace, 0);

    write_gateway
        .delete_all_for_field_category(seed.plan_id, seed.field_cultivation_id, "general")
        .expect("delete");

    let schedule_count_after_delete: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM task_schedules WHERE cultivation_plan_id = ?1",
                params![seed.plan_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(schedule_count_after_delete, 0);
}
