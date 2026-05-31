//! Parity: `test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb`

use super::crop_pest_gateway::CropPestSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::pest::gateways::CropPestGateway;

fn crop_pest_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_crop_pest_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "crop_pest_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE crop_pests (
              rowid INTEGER PRIMARY KEY AUTOINCREMENT,
              crop_id INTEGER NOT NULL, pest_id INTEGER NOT NULL,
              created_at TEXT, updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

// Ruby: create links crop and pest
#[test]
fn create_links_crop_and_pest() {
    let pool = crop_pest_test_pool();
    let gw = CropPestSqliteGateway::new(pool);
    let link = gw.create(1, 2).unwrap();
    assert_eq!(link.crop_id, 1);
    assert_eq!(link.pest_id, 2);
}

// Ruby: find_by_crop_id_and_pest_id returns link entity when present
#[test]
fn find_by_crop_id_and_pest_id_returns_link_when_present() {
    let pool = crop_pest_test_pool();
    let gw = CropPestSqliteGateway::new(pool);
    gw.create(1, 2).unwrap();
    let link = gw.find_by_crop_id_and_pest_id(1, 2).unwrap();
    assert!(link.is_some());
    let link = link.unwrap();
    assert_eq!(link.crop_id, 1);
    assert_eq!(link.pest_id, 2);
}

// Ruby: list_by_pest_id returns linked crop ids
#[test]
fn list_by_pest_id_returns_linked_crop_ids() {
    let pool = crop_pest_test_pool();
    let gw = CropPestSqliteGateway::new(pool);
    gw.create(1, 9).unwrap();
    gw.create(2, 9).unwrap();
    let mut ids = gw.list_by_pest_id(9).unwrap();
    ids.sort_unstable();
    assert_eq!(ids, vec![1, 2]);
}

// Ruby: delete removes association
#[test]
fn delete_removes_association() {
    let pool = crop_pest_test_pool();
    let gw = CropPestSqliteGateway::new(pool);
    gw.create(1, 2).unwrap();
    assert!(gw.delete(1, 2).unwrap());
    assert!(gw.find_by_crop_id_and_pest_id(1, 2).unwrap().is_none());
}
