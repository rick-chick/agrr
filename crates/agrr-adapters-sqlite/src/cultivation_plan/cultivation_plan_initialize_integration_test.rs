//! Integration test: plan initialize rolls back when a related insert fails mid-flight.

use super::{
    CultivationPlanFieldMutationSqliteGateway, CultivationPlanPlanCropSqliteGateway,
    CultivationPlanSqliteGateway,
};
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{CultivationPlanInitCrop, CultivationPlanInitFarm};
use agrr_domain::cultivation_plan::interactors::CultivationPlanInitializeInteractor;
use agrr_domain::shared::ports::{ClockPort, LoggerPort};

struct TestLogger;
impl LoggerPort for TestLogger {
    fn info(&self, _: &str) {}
    fn warn(&self, _: &str) {}
    fn error(&self, _: &str) {}
    fn debug(&self, _: &str) {}
}

struct TestClock;
impl ClockPort for TestClock {
    fn today(&self) -> time::Date {
        time::macros::date!(2026-03-01)
    }
    fn now(&self) -> time::OffsetDateTime {
        time::macros::datetime!(2026-03-01 0:00 UTC)
    }
}

const PLAN_INIT_INTEGRATION_DDL: &str = "
PRAGMA foreign_keys = ON;
CREATE TABLE farms (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL
);
CREATE TABLE crops (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL
);
CREATE TABLE cultivation_plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  farm_id INTEGER NOT NULL,
  user_id INTEGER,
  organization_id INTEGER,
  session_id TEXT,
  total_area REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  plan_type TEXT NOT NULL DEFAULT 'public',
  plan_year INTEGER,
  plan_name TEXT,
  planning_start_date TEXT,
  planning_end_date TEXT,
  optimization_phase TEXT,
  optimization_phase_message TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (farm_id) REFERENCES farms(id)
);
CREATE TABLE cultivation_plan_crops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cultivation_plan_id INTEGER NOT NULL,
  crop_id INTEGER,
  name TEXT NOT NULL,
  variety TEXT,
  area_per_unit REAL,
  revenue_per_area REAL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (cultivation_plan_id) REFERENCES cultivation_plans(id),
  FOREIGN KEY (crop_id) REFERENCES crops(id)
);
CREATE TABLE cultivation_plan_fields (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cultivation_plan_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  area REAL NOT NULL,
  daily_fixed_cost REAL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (cultivation_plan_id) REFERENCES cultivation_plans(id)
);
";

fn plan_init_integration_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_plan_init_it_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "plan_init_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| conn.execute_batch(PLAN_INIT_INTEGRATION_DDL))
        .unwrap();
    pool.with_write(|conn| {
        conn.execute("INSERT INTO farms (id, name) VALUES (1, 'Farm')", [])?;
        Ok(())
    })
    .unwrap();
    pool
}

#[test]
fn plan_initialize_rolls_back_orphan_plan_on_crop_insert_failure() {
    let pool = plan_init_integration_pool();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan_crop_gateway = CultivationPlanPlanCropSqliteGateway::new(pool.clone());
    let field_gateway = CultivationPlanFieldMutationSqliteGateway::new(pool.clone());
    let logger = TestLogger;
    let clock = TestClock;

    let interactor = CultivationPlanInitializeInteractor::new(
        CultivationPlanInitFarm {
            id: 1,
            name: "Farm".into(),
        },
        100.0,
        vec![CultivationPlanInitCrop {
            id: 99_999,
            name: "MissingCrop".into(),
            variety: None,
            area_per_unit: 1.0,
            revenue_per_area: 100.0,
        }],
        &plan_gateway,
        &plan_crop_gateway,
        &field_gateway,
        &clock,
        &logger,
    );

    let result = interactor.call().unwrap();
    assert!(
        !result.is_success(),
        "expected failure when crop FK is violated"
    );

    let plan_count: i64 = pool
        .with_read(|conn| conn.query_row("SELECT COUNT(*) FROM cultivation_plans", [], |r| r.get(0)))
        .unwrap();
    assert_eq!(
        plan_count, 0,
        "orphan cultivation_plans row must be rolled back"
    );
}

#[test]
fn plan_initialize_commits_plan_crops_and_fields_on_success() {
    let pool = plan_init_integration_pool();
    pool.with_write(|conn| {
        conn.execute("INSERT INTO crops (id, name) VALUES (10, 'Tomato')", [])?;
        Ok(())
    })
    .unwrap();

    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan_crop_gateway = CultivationPlanPlanCropSqliteGateway::new(pool.clone());
    let field_gateway = CultivationPlanFieldMutationSqliteGateway::new(pool.clone());
    let logger = TestLogger;
    let clock = TestClock;

    let interactor = CultivationPlanInitializeInteractor::new(
        CultivationPlanInitFarm {
            id: 1,
            name: "Farm".into(),
        },
        100.0,
        vec![CultivationPlanInitCrop {
            id: 10,
            name: "Tomato".into(),
            variety: Some("A".into()),
            area_per_unit: 1.0,
            revenue_per_area: 100.0,
        }],
        &plan_gateway,
        &plan_crop_gateway,
        &field_gateway,
        &clock,
        &logger,
    );

    let result = interactor.call().unwrap();
    assert!(
        result.is_success(),
        "expected success, got errors: {:?}",
        result.errors
    );

    let (plan_count, crop_count, field_count): (i64, i64, i64) = pool
        .with_read(|conn| {
            let plan_count: i64 =
                conn.query_row("SELECT COUNT(*) FROM cultivation_plans", [], |r| r.get(0))?;
            let crop_count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_crops",
                [],
                |r| r.get(0),
            )?;
            let field_count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_fields",
                [],
                |r| r.get(0),
            )?;
            Ok((plan_count, crop_count, field_count))
        })
        .unwrap();
    assert_eq!(plan_count, 1);
    assert_eq!(crop_count, 1);
    assert!(field_count >= 1);
}

#[test]
fn plan_initialize_rolls_back_plan_and_crops_on_field_insert_failure() {
    let pool = plan_init_integration_pool();
    pool.with_write(|conn| {
        conn.execute("INSERT INTO crops (id, name) VALUES (10, 'Tomato')", [])?;
        conn.execute_batch(
            "CREATE TRIGGER reject_field_insert BEFORE INSERT ON cultivation_plan_fields
             BEGIN
               SELECT RAISE(FAIL, 'field insert rejected for test');
             END;",
        )?;
        Ok(())
    })
    .unwrap();

    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan_crop_gateway = CultivationPlanPlanCropSqliteGateway::new(pool.clone());
    let field_gateway = CultivationPlanFieldMutationSqliteGateway::new(pool.clone());
    let logger = TestLogger;
    let clock = TestClock;

    let interactor = CultivationPlanInitializeInteractor::new(
        CultivationPlanInitFarm {
            id: 1,
            name: "Farm".into(),
        },
        100.0,
        vec![CultivationPlanInitCrop {
            id: 10,
            name: "Tomato".into(),
            variety: Some("A".into()),
            area_per_unit: 1.0,
            revenue_per_area: 100.0,
        }],
        &plan_gateway,
        &plan_crop_gateway,
        &field_gateway,
        &clock,
        &logger,
    );

    let result = interactor.call().unwrap();
    assert!(
        !result.is_success(),
        "expected failure when field insert is rejected"
    );

    let (plan_count, crop_count, field_count): (i64, i64, i64) = pool
        .with_read(|conn| {
            let plan_count: i64 =
                conn.query_row("SELECT COUNT(*) FROM cultivation_plans", [], |r| r.get(0))?;
            let crop_count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_crops",
                [],
                |r| r.get(0),
            )?;
            let field_count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_fields",
                [],
                |r| r.get(0),
            )?;
            Ok((plan_count, crop_count, field_count))
        })
        .unwrap();
    assert_eq!(plan_count, 0, "plan row must roll back when fields fail");
    assert_eq!(crop_count, 0, "crop rows must roll back when fields fail");
    assert_eq!(field_count, 0);
}
