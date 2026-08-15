//! Work hub read gateway — farms with field stats and optional private plan id.
//!
//! Representative `plan_id` per farm follows
//! [`work_hub_representative_plan_policy`](agrr_domain::work_record::policies::work_hub_representative_plan_policy).

use crate::pool::SqlitePool;
use agrr_domain::work_record::dtos::WorkHubFarmRow;
use agrr_domain::work_record::gateways::WorkHubReadGateway;
use agrr_domain::work_record::policies::work_hub_representative_plan_policy::{
    ACTIVE_PLAN_STATUS, DRAFT_PLAN_STATUS,
};
use rusqlite::params;

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
                    "SELECT f.id, f.name, \
                 (SELECT COUNT(*) FROM fields fld WHERE fld.farm_id = f.id AND COALESCE(fld.area, 0) > 0), \
                 (SELECT COALESCE(SUM(fld.area), 0) FROM fields fld WHERE fld.farm_id = f.id AND COALESCE(fld.area, 0) > 0), \
                 (SELECT cp.id FROM cultivation_plans cp \
                    WHERE cp.farm_id = f.id AND cp.user_id = ?1 AND cp.plan_type = 'private' \
                      AND cp.status IN (?2, ?3) \
                    ORDER BY CASE cp.status WHEN ?2 THEN 0 WHEN ?3 THEN 1 END, \
                             cp.updated_at DESC, cp.id DESC \
                    LIMIT 1) \
                 FROM farms f \
                 WHERE f.user_id = ?1 AND f.is_reference = 0 \
                 ORDER BY f.name COLLATE NOCASE",
                )?;
                let rows = stmt.query_map(
                    params![user_id, ACTIVE_PLAN_STATUS, DRAFT_PLAN_STATUS],
                    |row| {
                    let farm_id: i64 = row.get(0)?;
                    let farm_name: String = row.get(1)?;
                    let field_count: i32 = row.get(2)?;
                    let total_area: f64 = row.get(3)?;
                    let plan_id: Option<i64> = row.get(4)?;
                    Ok(WorkHubFarmRow {
                        farm_id,
                        farm_name,
                        field_count,
                        total_area,
                        has_valid_fields: field_count > 0,
                        plan_id,
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
    }

    fn insert_private_plan(
        conn: &rusqlite::Connection,
        id: i64,
        farm_id: i64,
        user_id: i64,
        status: &str,
        updated_at: &str,
    ) -> rusqlite::Result<()> {
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (?1, ?2, ?3, 100.0, 'private', ?4, ?5, datetime('now'), ?6)",
            params![id, farm_id, user_id, format!("Plan {id}"), status, updated_at],
        )?;
        Ok(())
    }

    #[test]
    fn list_farm_rows_prefers_latest_completed_over_pending_and_older_completed() {
        let pool = work_hub_test_pool();
        let user_id = 9_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (1, ?1, 'Farm A', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            insert_private_plan(conn, 100, 1, user_id, "pending", "2026-01-01 00:00:00")?;
            insert_private_plan(conn, 101, 1, user_id, "completed", "2026-01-02 00:00:00")?;
            insert_private_plan(conn, 102, 1, user_id, "completed", "2026-01-03 00:00:00")?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(102), rows[0].plan_id);
    }

    #[test]
    fn list_farm_rows_falls_back_to_latest_pending_when_no_completed() {
        let pool = work_hub_test_pool();
        let user_id = 10_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (1, ?1, 'Farm A', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            insert_private_plan(conn, 100, 1, user_id, "pending", "2026-01-01 00:00:00")?;
            insert_private_plan(conn, 101, 1, user_id, "pending", "2026-01-03 00:00:00")?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(101), rows[0].plan_id);
    }

    #[test]
    fn list_farm_rows_prefers_completed_even_when_pending_is_newer() {
        let pool = work_hub_test_pool();
        let user_id = 11_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (1, ?1, 'Farm A', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            insert_private_plan(conn, 100, 1, user_id, "completed", "2026-01-01 00:00:00")?;
            insert_private_plan(conn, 101, 1, user_id, "pending", "2026-01-05 00:00:00")?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(Some(100), rows[0].plan_id);
    }

    #[test]
    fn list_farm_rows_ignores_optimizing_and_failed_plans() {
        let pool = work_hub_test_pool();
        let user_id = 12_i64;
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (1, ?1, 'Farm A', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
                params![user_id],
            )?;
            insert_private_plan(conn, 100, 1, user_id, "optimizing", "2026-01-05 00:00:00")?;
            insert_private_plan(conn, 101, 1, user_id, "failed", "2026-01-06 00:00:00")?;
            Ok(())
        })
        .unwrap();

        let gw = WorkHubReadSqliteGateway::new(pool);
        let rows = gw.list_farm_rows_for_user(user_id).unwrap();

        assert_eq!(None, rows[0].plan_id);
    }
}
