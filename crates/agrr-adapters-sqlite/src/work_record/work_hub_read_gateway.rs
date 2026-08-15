//! Work hub read gateway — farms with field stats and optional private plan id.
//!
//! ## Representative private plan per farm
//!
//! One `plan_id` per farm for cross-farm variance / work entry. Selection (deterministic):
//!
//! 1. Prefer **`completed`** plans (workable / "active") — latest `updated_at`, then highest `id`.
//! 2. Else prefer **`pending`** ("draft") — same ordering.
//! 3. Else **`optimizing`** — same ordering.
//! 4. Else any other status — same ordering.
//!
//! Product terms in issues: active ≈ `completed`, draft ≈ `pending`.

use crate::pool::SqlitePool;
use agrr_domain::work_record::dtos::WorkHubFarmRow;
use agrr_domain::work_record::gateways::WorkHubReadGateway;
use rusqlite::params;

/// SQL `ORDER BY` for representative private plan (see module docs).
const REPRESENTATIVE_PLAN_ORDER: &str = "CASE cp.status \
    WHEN 'completed' THEN 0 \
    WHEN 'pending' THEN 1 \
    WHEN 'optimizing' THEN 2 \
    ELSE 3 END, cp.updated_at DESC, cp.id DESC";

pub struct WorkHubReadSqliteGateway {
    pool: SqlitePool,
}

impl WorkHubReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl WorkHubReadGateway for WorkHubReadSqliteGateway {
    fn list_farm_rows_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<WorkHubFarmRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    &format!(
                        "SELECT f.id, f.name, \
                 (SELECT COUNT(*) FROM fields fld WHERE fld.farm_id = f.id AND COALESCE(fld.area, 0) > 0), \
                 (SELECT COALESCE(SUM(fld.area), 0) FROM fields fld WHERE fld.farm_id = f.id AND COALESCE(fld.area, 0) > 0), \
                 (SELECT cp.id FROM cultivation_plans cp \
                    WHERE cp.farm_id = f.id AND cp.user_id = ?1 AND cp.plan_type = 'private' \
                    ORDER BY {REPRESENTATIVE_PLAN_ORDER} LIMIT 1), \
                 (SELECT cp.status FROM cultivation_plans cp \
                    WHERE cp.farm_id = f.id AND cp.user_id = ?1 AND cp.plan_type = 'private' \
                    ORDER BY {REPRESENTATIVE_PLAN_ORDER} LIMIT 1) \
                 FROM farms f \
                 WHERE f.user_id = ?1 AND f.is_reference = 0 \
                 ORDER BY f.name COLLATE NOCASE",
                        REPRESENTATIVE_PLAN_ORDER = REPRESENTATIVE_PLAN_ORDER
                    ),
                )?;
                let rows = stmt.query_map(params![user_id], |row| {
                    let farm_id: i64 = row.get(0)?;
                    let farm_name: String = row.get(1)?;
                    let field_count: i32 = row.get(2)?;
                    let total_area: f64 = row.get(3)?;
                    let plan_id: Option<i64> = row.get(4)?;
                    let representative_plan_status: Option<String> = row.get(5)?;
                    Ok(WorkHubFarmRow {
                        farm_id,
                        farm_name,
                        field_count,
                        total_area,
                        has_valid_fields: field_count > 0,
                        plan_id,
                        representative_plan_status,
                    })
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }
}

#[cfg(test)]
mod tests {
    use super::WorkHubReadSqliteGateway;
    use crate::pool::SqlitePool;
    use agrr_domain::work_record::gateways::WorkHubReadGateway;
    use rusqlite::params;

    fn work_hub_test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_work_hub_gw_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "work_hub_gw_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL,
              latitude REAL, longitude REAL, region TEXT, is_reference INTEGER NOT NULL DEFAULT 0,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE fields (
              id INTEGER PRIMARY KEY, farm_id INTEGER, name TEXT, area REAL,
              daily_fixed_cost REAL, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE cultivation_plans (
              id INTEGER PRIMARY KEY, farm_id INTEGER, user_id INTEGER,
              total_area REAL, plan_type TEXT, plan_name TEXT, status TEXT,
              created_at TEXT, updated_at TEXT
            );",
            )
        })
        .unwrap();
        pool
    }

    #[test]
    fn list_farm_rows_includes_field_stats_and_plan_id() {
        let pool = work_hub_test_pool();
        let user_id = 7_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (1, ?1, 'Farm A', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO fields (farm_id, name, area, created_at, updated_at)
             VALUES (1, 'Field 1', 40.0, datetime('now'), datetime('now')),
                    (1, 'Field 2', 60.0, datetime('now'), datetime('now'))",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (99, 1, ?1, 100.0, 'private', 'Plan A', 'pending', datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(1, rows.len());
        assert_eq!(1, rows[0].farm_id);
        assert_eq!("Farm A", rows[0].farm_name);
        assert_eq!(2, rows[0].field_count);
        assert!((rows[0].total_area - 100.0).abs() < f64::EPSILON);
        assert!(rows[0].has_valid_fields);
        assert_eq!(Some(99), rows[0].plan_id);
        assert_eq!(Some("pending".to_string()), rows[0].representative_plan_status);
    }

    #[test]
    fn list_farm_rows_marks_invalid_when_no_positive_area_fields() {
        let pool = work_hub_test_pool();
        let user_id = 8_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (2, ?1, 'Empty Farm', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO fields (farm_id, name, area, created_at, updated_at)
             VALUES (2, 'Field 0', 0, datetime('now'), datetime('now'))",
                [],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(1, rows.len());
        assert_eq!(0, rows[0].field_count);
        assert!(!rows[0].has_valid_fields);
        assert_eq!(None, rows[0].plan_id);
        assert_eq!(None, rows[0].representative_plan_status);
    }

    #[test]
    fn list_farm_rows_prefers_latest_completed_plan_over_pending() {
        let pool = work_hub_test_pool();
        let user_id = 11_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (3, ?1, 'Farm C', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO fields (farm_id, name, area, created_at, updated_at)
             VALUES (3, 'Field 1', 10.0, datetime('now'), datetime('now'))",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (200, 3, ?1, 10.0, 'private', 'Completed older', 'completed', datetime('now'), datetime('2020-01-01'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (201, 3, ?1, 10.0, 'private', 'Pending newer', 'pending', datetime('now'), datetime('2030-01-01'))",
                params![user_id],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(200), rows[0].plan_id);
        assert_eq!(Some("completed".to_string()), rows[0].representative_plan_status);
    }

    #[test]
    fn list_farm_rows_selects_latest_completed_when_multiple_completed() {
        let pool = work_hub_test_pool();
        let user_id = 12_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (4, ?1, 'Farm D', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO fields (farm_id, name, area, created_at, updated_at)
             VALUES (4, 'Field 1', 10.0, datetime('now'), datetime('now'))",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (300, 4, ?1, 10.0, 'private', 'Completed older', 'completed', datetime('now'), datetime('2020-01-01'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (301, 4, ?1, 10.0, 'private', 'Completed newer', 'completed', datetime('now'), datetime('2030-01-01'))",
                params![user_id],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(301), rows[0].plan_id);
        assert_eq!(Some("completed".to_string()), rows[0].representative_plan_status);
    }

    #[test]
    fn list_farm_rows_falls_back_to_latest_pending_when_no_completed() {
        let pool = work_hub_test_pool();
        let user_id = 13_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (5, ?1, 'Farm E', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO fields (farm_id, name, area, created_at, updated_at)
             VALUES (5, 'Field 1', 10.0, datetime('now'), datetime('now'))",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (400, 5, ?1, 10.0, 'private', 'Pending older', 'pending', datetime('now'), datetime('2020-01-01'))",
                params![user_id],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (401, 5, ?1, 10.0, 'private', 'Pending newer', 'pending', datetime('now'), datetime('2030-01-01'))",
                params![user_id],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(401), rows[0].plan_id);
        assert_eq!(Some("pending".to_string()), rows[0].representative_plan_status);
    }
}
