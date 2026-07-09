//! Integration: `DeletionUndoSqliteGateway::perform_restore` state machine.

use super::schedule::schedule_destroy;
use super::DeletionUndoSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use rusqlite::params;
use std::collections::BTreeMap;

fn deletion_undo_gateway_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_du_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "du_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE interaction_rules (
              id INTEGER PRIMARY KEY, user_id INTEGER, rule_type TEXT NOT NULL,
              source_group TEXT NOT NULL, target_group TEXT NOT NULL, impact_ratio REAL NOT NULL,
              is_directional INTEGER NOT NULL DEFAULT 1, description TEXT, region TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0, created_at TEXT, updated_at TEXT
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

fn insert_undo_event(pool: &SqlitePool, token: &str, state: &str, snapshot: &str) {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO deletion_undo_events (
               id, resource_type, resource_id, snapshot, metadata, expires_at, state, created_at, updated_at
             ) VALUES (?1, 'InteractionRule', '1', ?2, '{}', datetime('now', '+1 hour'), ?3, datetime('now'), datetime('now'))",
            params![token, snapshot, state],
        )
    })
    .unwrap();
}

fn undo_event_state(pool: &SqlitePool, token: &str) -> String {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT state FROM deletion_undo_events WHERE id = ?1",
            params![token],
            |row| row.get(0),
        )
    })
    .unwrap()
}

fn schedule_interaction_rule_undo(pool: &SqlitePool) -> (i64, String) {
    let rule_id = pool
        .with_write(|conn| {
            conn.execute(
                "INSERT INTO interaction_rules (
                   user_id, rule_type, source_group, target_group, impact_ratio,
                   is_directional, region, is_reference, created_at, updated_at
                 ) VALUES (42, 'continuous_cultivation', 'ナス科', 'ナス科', 0.7, 1, 'jp', 0, datetime('now'), datetime('now'))",
                [],
            )?;
            Ok(conn.last_insert_rowid())
        })
        .unwrap();

    let scheduled = schedule_destroy(
        pool,
        "InteractionRule",
        rule_id,
        42,
        "削除しました",
        5,
        BTreeMap::new(),
    )
    .expect("schedule_destroy");

    (rule_id, scheduled.undo_token)
}

#[test]
fn perform_restore_not_found_returns_deletion_undo_not_found_error() {
    let pool = deletion_undo_gateway_test_pool();
    let gateway = DeletionUndoSqliteGateway::new(pool);

    let err = gateway
        .perform_restore("missing-token")
        .expect_err("expected not found");

    assert!(err.is::<DeletionUndoNotFoundError>());
}

#[test]
fn perform_restore_non_scheduled_state_returns_conflict() {
    let pool = deletion_undo_gateway_test_pool();
    insert_undo_event(&pool, "expired-token", "expired", "{}");
    let gateway = DeletionUndoSqliteGateway::new(pool);

    let err = gateway
        .perform_restore("expired-token")
        .expect_err("expected conflict");

    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .expect("DeletionUndoRestoreConflictError");
    assert_eq!(conflict.0, "undo event is not scheduled");
}

#[test]
fn perform_restore_success_marks_event_restored() {
    let pool = deletion_undo_gateway_test_pool();
    let (rule_id, undo_token) = schedule_interaction_rule_undo(&pool);
    let gateway = DeletionUndoSqliteGateway::new(pool.clone());

    gateway.perform_restore(&undo_token).expect("restore");

    assert_eq!(undo_event_state(&pool, &undo_token), "restored");

    let count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM interaction_rules WHERE id = ?1",
                params![rule_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(count, 1);
}

#[test]
fn perform_restore_twice_returns_conflict() {
    let pool = deletion_undo_gateway_test_pool();
    let (_, undo_token) = schedule_interaction_rule_undo(&pool);
    let gateway = DeletionUndoSqliteGateway::new(pool);

    gateway.perform_restore(&undo_token).expect("first restore");

    let err = gateway
        .perform_restore(&undo_token)
        .expect_err("expected second restore conflict");

    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .expect("DeletionUndoRestoreConflictError");
    assert_eq!(conflict.0, "undo event is not scheduled");
}
