//! Integration: `schedule_destroy` wraps snapshot + undo INSERT + DELETE in one SQL transaction.

use super::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use rusqlite::params;
use std::collections::BTreeMap;

fn schedule_destroy_transaction_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_du_txn_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "du_txn_{}_{}.sqlite3",
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
               id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, name TEXT NOT NULL,
               region TEXT, latitude REAL, longitude REAL, weather_location_id INTEGER,
               is_reference INTEGER NOT NULL DEFAULT 0, created_at TEXT, updated_at TEXT
             );
             CREATE TABLE fields (
               id INTEGER PRIMARY KEY, farm_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
               name TEXT NOT NULL, area REAL, daily_fixed_cost REAL,
               region TEXT, created_at TEXT, updated_at TEXT
             );
             CREATE TABLE deletion_undo_events (
               id TEXT PRIMARY KEY, resource_type TEXT NOT NULL, resource_id TEXT NOT NULL,
               snapshot TEXT NOT NULL DEFAULT '{}', metadata TEXT NOT NULL DEFAULT '{}',
               deleted_by_id INTEGER, expires_at TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'scheduled',
               restored_at TEXT, finalized_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
             );",
        )
    })
    .unwrap();
    pool
}

fn insert_farm_with_field(pool: &SqlitePool) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (user_id, name, region, latitude, longitude, is_reference, created_at, updated_at)
             VALUES (1, 'Test Farm', 'jp', 35.0, 139.0, 0, datetime('now'), datetime('now'))",
            [],
        )?;
        let farm_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, region, created_at, updated_at)
             VALUES (?1, 1, 'Field A', 100.0, 0.0, 'jp', datetime('now'), datetime('now'))",
            params![farm_id],
        )?;
        Ok(farm_id)
    })
    .unwrap()
}

fn install_farm_delete_abort_trigger(pool: &SqlitePool) {
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TRIGGER fail_farm_delete BEFORE DELETE ON farms
             BEGIN
               SELECT RAISE(ABORT, 'simulated delete failure');
             END;",
        )
    })
    .unwrap();
}

#[test]
fn schedule_destroy_rolls_back_undo_event_and_partial_deletes_when_delete_fails() {
    let pool = schedule_destroy_transaction_test_pool();
    let farm_id = insert_farm_with_field(&pool);
    install_farm_delete_abort_trigger(&pool);

    let result = schedule_destroy(
        &pool,
        "Farm",
        farm_id,
        1,
        "削除しました",
        5,
        BTreeMap::new(),
    );
    assert!(result.is_err(), "delete failure should propagate");

    let undo_count: i64 = pool
        .with_read(|conn| {
            conn.query_row("SELECT COUNT(*) FROM deletion_undo_events", [], |row| row.get(0))
        })
        .unwrap();
    assert_eq!(
        undo_count, 0,
        "undo event must not persist when delete graph fails"
    );

    let farm_count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM farms WHERE id = ?1",
                params![farm_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(farm_count, 1, "farm row must remain after rollback");

    let field_count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM fields WHERE farm_id = ?1",
                params![farm_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(
        field_count, 1,
        "field rows must not be partially deleted when farm delete fails"
    );
}
