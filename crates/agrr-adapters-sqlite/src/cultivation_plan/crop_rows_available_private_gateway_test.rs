// Parity: private plan workbench available_crops — owned user crops scoped to farm region.

use crate::cultivation_plan::CropRowsAvailablePrivateSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use agrr_domain::cultivation_plan::gateways::CropRowsAvailableGateway;
use rusqlite::params;

fn test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!(
        "agrr_crop_rows_private_test_{}",
        std::process::id()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "crop_rows_private_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE crops (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL, variety TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0, area_per_unit REAL, revenue_per_area REAL,
              region TEXT, groups TEXT, created_at TEXT, updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_crop(
    pool: &SqlitePool,
    user_id: i64,
    name: &str,
    is_reference: bool,
    region: &str,
) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO crops (user_id, name, is_reference, region, groups, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, '[]', datetime('now'), datetime('now'))",
            params![user_id, name, if is_reference { 1 } else { 0 }, region],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

fn private_auth(user_id: i64) -> serde_json::Value {
    serde_json::to_value(CultivationPlanRestAuth::private(user_id)).unwrap()
}

#[test]
fn list_by_farm_region_returns_only_owned_crops_in_farm_region() {
    let pool = test_pool();
    let gw = CropRowsAvailablePrivateSqliteGateway::new(pool.clone());
    let user_id = 1;

    let jp_owned = insert_crop(&pool, user_id, "トマト", false, "jp");
    insert_crop(&pool, user_id, "US作物", false, "us");
    insert_crop(&pool, 0, "JP参照", true, "jp");
    insert_crop(&pool, 0, "US参照", true, "us");
    insert_crop(&pool, 2, "他人作物", false, "jp");

    let rows = gw
        .list_by_farm_region(&private_auth(user_id), Some("jp"))
        .unwrap();
    let ids: Vec<i64> = rows.iter().map(|r| r.id).collect();

    assert_eq!(ids, vec![jp_owned]);
}

#[test]
fn list_by_farm_region_without_region_returns_all_owned_non_reference_crops() {
    let pool = test_pool();
    let gw = CropRowsAvailablePrivateSqliteGateway::new(pool.clone());
    let user_id = 1;

    let jp = insert_crop(&pool, user_id, "JP", false, "jp");
    let us = insert_crop(&pool, user_id, "US", false, "us");
    insert_crop(&pool, 0, "参照", true, "jp");

    let rows = gw
        .list_by_farm_region(&private_auth(user_id), None)
        .unwrap();
    let mut ids: Vec<i64> = rows.iter().map(|r| r.id).collect();
    ids.sort();

    let mut expected = vec![jp, us];
    expected.sort();
    assert_eq!(ids, expected);
}
