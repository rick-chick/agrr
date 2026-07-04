//! Integration: `DeletionUndoSqliteGateway::perform_restore` state machine.

use super::DeletionUndoSqliteGateway;
use crate::interaction_rule::InteractionRuleSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use agrr_domain::interaction_rule::gateways::{
    InteractionRuleGateway, SoftDeleteWithUndoOutcome,
};
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::user::User;
use rusqlite::params;

struct StubTranslator;

impl TranslatorPort for StubTranslator {
    fn translate(&self, key: &str, _: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(
        &self,
        _: time::Date,
        _: Option<&str>,
        _: &TranslateOptions,
    ) -> String {
        String::new()
    }
}

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

fn insert_undo_event(pool: &SqlitePool, token: &str, state: &str, snapshot: &str) {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO deletion_undo_events (
               id, resource_type, resource_id, snapshot, metadata,
               expires_at, state, created_at, updated_at
             ) VALUES (?1, 'InteractionRule', '1', ?2, '{}', datetime('now', '+1 day'), ?3, datetime('now'), datetime('now'))",
            params![token, snapshot, state],
        )
    })
    .unwrap();
}

fn undo_state(pool: &SqlitePool, token: &str) -> String {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT state FROM deletion_undo_events WHERE id = ?1",
            params![token],
            |row| row.get(0),
        )
    })
    .unwrap()
}

fn assert_not_found(err: Box<dyn std::error::Error + Send + Sync>) {
    assert!(
        err.downcast_ref::<DeletionUndoNotFoundError>().is_some(),
        "expected DeletionUndoNotFoundError, got {err}"
    );
}

fn assert_restore_conflict(err: Box<dyn std::error::Error + Send + Sync>, expected_substr: &str) {
    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .unwrap_or_else(|| panic!("expected DeletionUndoRestoreConflictError, got {err}"));
    assert!(
        conflict.0.contains(expected_substr),
        "expected conflict message containing {expected_substr:?}, got {:?}",
        conflict.0
    );
}

fn schedule_interaction_rule_undo(pool: &SqlitePool) -> (i64, String) {
    let user = User::new(42, false);
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
    let rule_id = created.id.expect("id");

    let SoftDeleteWithUndoOutcome::Success(success) =
        gw.soft_delete_with_undo(&user, rule_id, 5000, &StubTranslator)
            .expect("soft delete")
    else {
        panic!("expected soft delete success");
    };
    let undo_token = success
        .undo
        .get("undo_token")
        .and_then(|v| v.as_str())
        .expect("undo_token")
        .to_string();
    (rule_id, undo_token)
}

#[test]
fn perform_restore_returns_not_found_for_unknown_token() {
    let pool = gateway_test_pool();
    let gw = DeletionUndoSqliteGateway::new(pool);
    let err = gw
        .perform_restore("missing-undo-token")
        .expect_err("unknown token");
    assert_not_found(err);
}

#[test]
fn perform_restore_rejects_non_scheduled_state() {
    let pool = gateway_test_pool();
    insert_undo_event(
        &pool,
        "already-restored",
        "restored",
        r#"{"model":"InteractionRule","attributes":{"id":1}}"#,
    );
    let gw = DeletionUndoSqliteGateway::new(pool);
    let err = gw
        .perform_restore("already-restored")
        .expect_err("non-scheduled");
    assert_restore_conflict(err, "not scheduled");
}

#[test]
fn perform_restore_restores_row_and_marks_event_restored() {
    let pool = gateway_test_pool();
    let (rule_id, undo_token) = schedule_interaction_rule_undo(&pool);
    let gw = DeletionUndoSqliteGateway::new(pool.clone());

    gw.perform_restore(&undo_token).expect("restore");

    assert_eq!(undo_state(&pool, &undo_token), "restored");
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
fn perform_restore_rejects_double_restore() {
    let pool = gateway_test_pool();
    let (_rule_id, undo_token) = schedule_interaction_rule_undo(&pool);
    let gw = DeletionUndoSqliteGateway::new(pool.clone());

    gw.perform_restore(&undo_token).expect("first restore");
    let err = gw.perform_restore(&undo_token).expect_err("second restore");
    assert_restore_conflict(err, "not scheduled");
    assert_eq!(undo_state(&pool, &undo_token), "restored");
}
