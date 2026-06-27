//! Integration: `DeletionUndoSqliteGateway::perform_restore` state machine.

use super::DeletionUndoSqliteGateway;
use super::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use crate::work_record::work_record_integration_fixture::{
    seed_work_record_crud, work_record_integration_pool,
};
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use rusqlite::params;
use std::collections::BTreeMap;

fn ensure_deletion_undo_events_table(pool: &SqlitePool) {
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS deletion_undo_events (
              id TEXT NOT NULL PRIMARY KEY,
              resource_type TEXT NOT NULL,
              resource_id TEXT NOT NULL,
              snapshot TEXT NOT NULL,
              metadata TEXT NOT NULL,
              deleted_by_id INTEGER,
              expires_at TEXT NOT NULL,
              state TEXT NOT NULL DEFAULT 'scheduled',
              restored_at TEXT,
              finalized_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );",
        )
    })
    .unwrap();
}

fn event_state(pool: &SqlitePool, undo_token: &str) -> String {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT state FROM deletion_undo_events WHERE id = ?1",
            params![undo_token],
            |row| row.get(0),
        )
    })
    .unwrap()
}

#[test]
fn perform_restore_marks_event_restored_and_restores_plan_graph() {
    let pool = work_record_integration_pool();
    ensure_deletion_undo_events_table(&pool);
    let seed = seed_work_record_crud(&pool);

    let scheduled = schedule_destroy(
        &pool,
        "CultivationPlan",
        seed.plan_id,
        42,
        "削除しました",
        5,
        BTreeMap::new(),
    )
    .expect("schedule destroy");
    assert_eq!(event_state(&pool, &scheduled.undo_token), "scheduled");

    DeletionUndoSqliteGateway::new(pool.clone())
        .perform_restore(&scheduled.undo_token)
        .expect("perform restore");

    assert_eq!(event_state(&pool, &scheduled.undo_token), "restored");

    let plan_count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plans WHERE id = ?1",
                params![seed.plan_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(plan_count, 1, "plan graph must be restored via gateway path");
}

#[test]
fn perform_restore_rejects_second_restore_with_conflict() {
    let pool = work_record_integration_pool();
    ensure_deletion_undo_events_table(&pool);
    let seed = seed_work_record_crud(&pool);

    let scheduled = schedule_destroy(
        &pool,
        "CultivationPlan",
        seed.plan_id,
        42,
        "削除しました",
        5,
        BTreeMap::new(),
    )
    .expect("schedule destroy");

    let gateway = DeletionUndoSqliteGateway::new(pool.clone());
    gateway
        .perform_restore(&scheduled.undo_token)
        .expect("first restore");

    let err = gateway
        .perform_restore(&scheduled.undo_token)
        .expect_err("second restore must conflict");
    assert!(
        err.downcast_ref::<DeletionUndoRestoreConflictError>().is_some(),
        "expected DeletionUndoRestoreConflictError, got {err:?}"
    );
    assert_eq!(event_state(&pool, &scheduled.undo_token), "restored");
}

#[test]
fn perform_restore_returns_not_found_for_unknown_token() {
    let pool = work_record_integration_pool();
    ensure_deletion_undo_events_table(&pool);

    let err = DeletionUndoSqliteGateway::new(pool)
        .perform_restore("nonexistent-undo-token")
        .expect_err("unknown token must not restore");
    assert!(
        err.downcast_ref::<DeletionUndoNotFoundError>().is_some(),
        "expected DeletionUndoNotFoundError, got {err:?}"
    );
}
