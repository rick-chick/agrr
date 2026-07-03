//! Integration: `DeletionUndoSqliteGateway::perform_restore` state machine.

use super::DeletionUndoSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::user::User;
use agrr_domain::interaction_rule::gateways::{
    InteractionRuleGateway, SoftDeleteWithUndoOutcome,
};
use crate::interaction_rule::interaction_rule_gateway::InteractionRuleSqliteGateway;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
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

fn schedule_interaction_rule_undo(pool: &SqlitePool) -> String {
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

    let SoftDeleteWithUndoOutcome::Success(success) = gw
        .soft_delete_with_undo(&user, rule_id, 5000, &StubTranslator)
        .expect("soft delete")
    else {
        panic!("expected soft delete success");
    };

    success
        .undo
        .get("undo_token")
        .and_then(|v| v.as_str())
        .expect("undo_token")
        .to_string()
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
fn perform_restore_not_found_for_unknown_token() {
    let pool = gateway_test_pool();
    let gw = DeletionUndoSqliteGateway::new(pool);

    let err = gw
        .perform_restore("missing-token")
        .expect_err("unknown token must fail");

    assert!(err.downcast_ref::<DeletionUndoNotFoundError>().is_some());
}

#[test]
fn perform_restore_success_sets_state_to_restored() {
    let pool = gateway_test_pool();
    let token = schedule_interaction_rule_undo(&pool);
    let gw = DeletionUndoSqliteGateway::new(pool.clone());

    gw.perform_restore(&token).expect("restore");

    assert_eq!(event_state(&pool, &token), "restored");
}

#[test]
fn perform_restore_double_restore_returns_conflict() {
    let pool = gateway_test_pool();
    let token = schedule_interaction_rule_undo(&pool);
    let gw = DeletionUndoSqliteGateway::new(pool);

    gw.perform_restore(&token).expect("first restore");

    let err = gw.perform_restore(&token).expect_err("second restore must fail");
    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .expect("conflict error");
    assert!(
        conflict.0.contains("not scheduled"),
        "expected scheduled-state conflict, got: {}",
        conflict.0
    );
}

#[test]
fn perform_restore_non_scheduled_state_returns_conflict() {
    let pool = gateway_test_pool();
    let token = schedule_interaction_rule_undo(&pool);
    pool.with_write(|conn| {
        conn.execute(
            "UPDATE deletion_undo_events SET state = 'expired' WHERE id = ?1",
            params![token],
        )
    })
    .unwrap();

    let gw = DeletionUndoSqliteGateway::new(pool);
    let err = gw
        .perform_restore(&token)
        .expect_err("expired event must not restore");

    let conflict = err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .expect("conflict error");
    assert!(
        conflict.0.contains("not scheduled"),
        "expected scheduled-state conflict, got: {}",
        conflict.0
    );
}
