//! Minimal SQLite schema + seed for work record gateway integration tests.

use crate::pool::SqlitePool;
use rusqlite::params;

pub struct WorkRecordCrudSeed {
    pub plan_id: i64,
    pub field_cultivation_id: i64,
    pub task_schedule_item_id: i64,
    pub agricultural_task_id: i64,
}

pub fn work_record_integration_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_work_record_it_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "work_record_it_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| conn.execute_batch(WORK_RECORD_INTEGRATION_DDL))
        .unwrap();
    pool
}

const WORK_RECORD_INTEGRATION_DDL: &str = "
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
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE agricultural_tasks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  name TEXT NOT NULL,
  task_type TEXT,
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
CREATE TABLE cultivation_plan_fields (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  area REAL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE cultivation_plan_crops (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  crop_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE field_cultivations (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  cultivation_plan_field_id INTEGER NOT NULL,
  cultivation_plan_crop_id INTEGER NOT NULL,
  area REAL,
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
  stage_name TEXT,
  stage_order INTEGER,
  scheduled_date TEXT,
  amount REAL,
  amount_unit TEXT,
  status TEXT,
  agricultural_task_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE work_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  cultivation_plan_id INTEGER NOT NULL,
  field_cultivation_id INTEGER,
  task_schedule_item_id INTEGER,
  agricultural_task_id INTEGER,
  name TEXT NOT NULL,
  task_type TEXT,
  actual_date TEXT NOT NULL,
  amount TEXT,
  amount_unit TEXT,
  time_spent_minutes INTEGER,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (cultivation_plan_id) REFERENCES cultivation_plans (id),
  FOREIGN KEY (task_schedule_item_id) REFERENCES task_schedule_items (id) ON DELETE SET NULL
);
CREATE INDEX index_work_records_on_plan_and_date
  ON work_records (cultivation_plan_id, actual_date);
CREATE INDEX index_work_records_on_task_schedule_item_id
  ON work_records (task_schedule_item_id);
CREATE TABLE deletion_undo_events (
  id TEXT PRIMARY KEY,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  snapshot TEXT NOT NULL DEFAULT '{}',
  metadata TEXT NOT NULL DEFAULT '{}',
  deleted_by_id INTEGER,
  expires_at TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'scheduled',
  restored_at TEXT,
  finalized_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
";

pub fn seed_work_record_crud(pool: &SqlitePool) -> WorkRecordCrudSeed {
    let farm_id = 1_i64;
    let plan_id = 10_i64;
    let crop_id = 100_i64;
    let agricultural_task_id = 50_i64;
    let plan_field_id = 200_i64;
    let plan_crop_id = 201_i64;
    let field_cultivation_id = 300_i64;
    let task_schedule_id = 400_i64;

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (?1, 42, 'Test Farm', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
            params![farm_id],
        )?;
        conn.execute(
            "INSERT INTO crops (id, user_id, name, variety, is_reference, created_at, updated_at)
             VALUES (?1, 42, 'Test Crop', 'V1', 0, datetime('now'), datetime('now'))",
            params![crop_id],
        )?;
        conn.execute(
            "INSERT INTO agricultural_tasks (id, user_id, name, task_type, is_reference, created_at, updated_at)
             VALUES (?1, 42, '除草', 'field_work', 0, datetime('now'), datetime('now'))",
            params![agricultural_task_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_year, plan_name, planning_start_date, planning_end_date, status, created_at, updated_at)
             VALUES (?1, ?2, 42, 50.0, 'private', 2026, '作業実績テスト', '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now'))",
            params![plan_id, farm_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name, area, created_at, updated_at)
             VALUES (?1, ?2, 'F1', 50.0, datetime('now'), datetime('now'))",
            params![plan_field_id, plan_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, crop_id, name, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'Test Crop', datetime('now'), datetime('now'))",
            params![plan_crop_id, plan_id, crop_id],
        )?;
        conn.execute(
            "INSERT INTO field_cultivations (id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, area, status, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, 50.0, 'completed', datetime('now'), datetime('now'))",
            params![field_cultivation_id, plan_id, plan_field_id, plan_crop_id],
        )?;
        conn.execute(
            "INSERT INTO task_schedules (id, cultivation_plan_id, field_cultivation_id, category, status, source, generated_at, created_at, updated_at)
             VALUES (?1, ?2, ?3, 'general', 'active', 'reference', datetime('now'), datetime('now'), datetime('now'))",
            params![task_schedule_id, plan_id, field_cultivation_id],
        )?;
        conn.execute(
            "INSERT INTO task_schedule_items (task_schedule_id, task_type, name, stage_name, stage_order, scheduled_date, amount, amount_unit, agricultural_task_id, status, created_at, updated_at)
             VALUES (?1, 'field_work', '除草作業', '初期', 1, '2026-06-02', 2.5, 'kg', ?2, 'planned', datetime('now'), datetime('now'))",
            params![task_schedule_id, agricultural_task_id],
        )?;
        Ok(())
    })
    .unwrap();

    let task_schedule_item_id = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT id FROM task_schedule_items WHERE task_schedule_id = ?1 LIMIT 1",
                params![task_schedule_id],
                |r| r.get(0),
            )
        })
        .unwrap();

    WorkRecordCrudSeed {
        plan_id,
        field_cultivation_id,
        task_schedule_item_id,
        agricultural_task_id,
    }
}
