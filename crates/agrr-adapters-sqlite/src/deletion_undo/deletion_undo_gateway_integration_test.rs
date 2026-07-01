//! Gateway-level `perform_restore` state machine: not-found, success, double-restore conflict.

use super::schedule::schedule_destroy;
use super::DeletionUndoSqliteGateway;
use crate::interaction_rule::InteractionRuleSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use agrr_domain::interaction_rule::gateways::InteractionRuleGateway;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::user::User;
use rusqlite::params;

fn gateway_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_undo_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "undo_gw_{}_{}.sqlite3",
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

fn seed_interaction_rule(pool: &SqlitePool) -> i64 {
    let user = User::new(7, false);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let created = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("jp")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    created.id.expect("id")
}

fn event_state(pool: &SqlitePool, token: &str) -> String {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT state FROM deletion_undo_events WHERE id = ?1",
            params![token],
            |row| row.get(0),
        )
    })
    .unwrap()
}

#[test]
fn perform_restore_returns_not_found_for_missing_token() {
    let pool = gateway_test_pool();
    let gw = DeletionUndoSqliteGateway::new(pool);

    let err = gw
        .perform_restore("missing-undo-token")
        .expect_err("missing token");

    assert!(err.downcast_ref::<DeletionUndoNotFoundError>().is_some());
}

#[test]
fn perform_restore_succeeds_and_marks_event_restored() {
    let pool = gateway_test_pool();
    let rule_id = seed_interaction_rule(&pool);

    let scheduled = schedule_destroy(
        &pool,
        "InteractionRule",
        rule_id,
        7,
        "削除しました",
        5,
        Default::default(),
    )
    .unwrap();

    let gw = DeletionUndoSqliteGateway::new(pool.clone());
    gw.perform_restore(&scheduled.undo_token)
        .expect("first restore");

    assert_eq!(event_state(&pool, &scheduled.undo_token), "restored");
}

#[test]
fn perform_restore_returns_conflict_on_double_restore() {
    let pool = gateway_test_pool();
    let rule_id = seed_interaction_rule(&pool);

    let scheduled = schedule_destroy(
        &pool,
        "InteractionRule",
        rule_id,
        7,
        "削除しました",
        5,
        Default::default(),
    )
    .unwrap();

    let gw = DeletionUndoSqliteGateway::new(pool);
    gw.perform_restore(&scheduled.undo_token)
        .expect("first restore");

    let err = gw
        .perform_restore(&scheduled.undo_token)
        .expect_err("second restore");

    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .expect("conflict error");
    assert!(conflict.0.contains("not scheduled"));
}
