//! Parity: `CultivationPlanPrivateReadActiveRecordGateway` index rows include `farm_id`.

use super::private_read_gateway::CultivationPlanPrivateReadSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::gateways::CultivationPlanPrivateReadGateway;
use rusqlite::params;

fn private_read_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_private_read_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "private_read_gw_{}_{}.sqlite3",
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
            CREATE TABLE cultivation_plans (
              id INTEGER PRIMARY KEY, farm_id INTEGER, user_id INTEGER,
              total_area REAL, plan_type TEXT, plan_name TEXT, status TEXT,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE cultivation_plan_crops (
              id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER
            );
            CREATE TABLE cultivation_plan_fields (
              id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER
            );",
        )
    })
    .unwrap();
    pool
}

#[test]
fn list_private_plan_index_rows_includes_farm_id() {
    let pool = private_read_test_pool();
    let user_id = 3_i64;
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (id, user_id, name, latitude, longitude, region, is_reference, created_at, updated_at)
             VALUES (10, ?1, 'Farm X', 35.0, 139.0, 'jp', 0, datetime('now'), datetime('now'))",
            params![user_id],
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, farm_id, user_id, total_area, plan_type, plan_name, status, created_at, updated_at)
             VALUES (20, 10, ?1, 50.0, 'private', 'Plan X', 'pending', datetime('now'), datetime('now'))",
            params![user_id],
        )?;
        Ok(())
    })
    .unwrap();

    let gw = CultivationPlanPrivateReadSqliteGateway::new(pool);
    let rows = gw
        .list_private_plan_index_rows_by_user_id(user_id)
        .unwrap();

    assert_eq!(1, rows.len());
    assert_eq!(10, rows[0].farm_id);
    assert_eq!(20, rows[0].id);
}
