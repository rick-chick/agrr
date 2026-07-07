//! Gateway-level `perform_restore` state machine (not-found, success, double-restore conflict).

use super::deletion_undo_gateway::DeletionUndoSqliteGateway;
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
use time::{format_description::well_known::Iso8601, OffsetDateTime};

use crate::interaction_rule::InteractionRuleSqliteGateway;

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

fn deletion_undo_gateway_pool() -> SqlitePool {
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
fn perform_restore_returns_not_found_for_unknown_token() {
    let pool = deletion_undo_gateway_pool();
    let gw = DeletionUndoSqliteGateway::new(pool);

    let err = gw
        .perform_restore("missing-token")
        .expect_err("unknown token");
    assert!(err.downcast_ref::<DeletionUndoNotFoundError>().is_some());
}

#[test]
fn perform_restore_marks_event_restored_and_rejects_second_restore() {
    let pool = deletion_undo_gateway_pool();
    let user = User::new(42, false);
    let rule_gw = InteractionRuleSqliteGateway::new(pool.clone());
    let created = rule_gw
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

    let SoftDeleteWithUndoOutcome::Success(success) = rule_gw
        .soft_delete_with_undo(&user, rule_id, 5000, &StubTranslator)
        .expect("soft delete")
    else {
        panic!("expected soft delete success");
    };
    let undo_token = success
        .undo
        .get("undo_token")
        .and_then(|v| v.as_str())
        .expect("undo_token");

    let undo_gw = DeletionUndoSqliteGateway::new(pool.clone());
    undo_gw.perform_restore(undo_token).expect("first restore");
    assert_eq!(event_state(&pool, undo_token), "restored");

    let count_after_restore: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM interaction_rules WHERE id = ?1",
                params![rule_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(count_after_restore, 1);

    let err = undo_gw
        .perform_restore(undo_token)
        .expect_err("second restore must conflict");
    assert!(err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .is_some());
}

#[test]
fn perform_restore_rejects_non_scheduled_state() {
    let pool = deletion_undo_gateway_pool();
    let token = "already-restored-token";
    let expires_at = (OffsetDateTime::now_utc() + time::Duration::hours(1))
        .format(&Iso8601::DEFAULT)
        .unwrap();
    let now = OffsetDateTime::now_utc()
        .format(&Iso8601::DEFAULT)
        .unwrap();
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO deletion_undo_events \
             (id, resource_type, resource_id, snapshot, metadata, expires_at, state, created_at, updated_at) \
             VALUES (?1, 'InteractionRule', '1', '{}', '{}', ?2, 'restored', ?3, ?3)",
            params![token, expires_at, now],
        )
    })
    .unwrap();

    let gw = DeletionUndoSqliteGateway::new(pool);
    let err = gw.perform_restore(token).expect_err("non-scheduled state");
    assert!(err
        .downcast_ref::<DeletionUndoRestoreConflictError>()
        .is_some());
}
