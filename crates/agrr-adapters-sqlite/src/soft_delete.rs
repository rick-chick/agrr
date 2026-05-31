//! Shared soft-delete → undo JSON for master gateways.

use crate::deletion_undo::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use agrr_domain::shared::dtos::Error;
use serde_json::json;
use std::collections::BTreeMap;

pub enum SoftDeleteJsonOutcome {
    Success(serde_json::Value),
    Failure(Error),
}

pub fn schedule_soft_delete_json(
    pool: SqlitePool,
    resource_type: &str,
    resource_id: i64,
    actor_id: i64,
    toast_message: &str,
    auto_hide_after: i64,
    _resource_label: Option<&str>,
) -> SoftDeleteJsonOutcome {
    match schedule_destroy(
        &pool,
        resource_type,
        resource_id,
        actor_id,
        toast_message,
        auto_hide_after,
        BTreeMap::new(),
    ) {
        Ok(scheduled) => {
            let meta = scheduled.metadata;
            let meta_obj = meta.as_object();
            let undo_token = scheduled.undo_token.clone();
            let toast = meta_obj
                .and_then(|m| m.get("toast_message"))
                .and_then(|v| v.as_str())
                .unwrap_or(toast_message);
            let undo_deadline = meta_obj
                .and_then(|m| m.get("undo_deadline"))
                .cloned()
                .unwrap_or_else(|| json!(scheduled.expires_at));
            SoftDeleteJsonOutcome::Success(json!({
                "undo_token": undo_token,
                "undo_deadline": undo_deadline,
                "toast_message": toast,
                "undo_path": format!("/undo_deletion?undo_token={undo_token}"),
                "auto_hide_after": meta_obj
                    .and_then(|m| m.get("auto_hide_after"))
                    .cloned()
                    .unwrap_or_else(|| json!(auto_hide_after)),
                "resource": meta_obj.and_then(|m| m.get("resource_label")).cloned(),
                "redirect_path": "/",
                "resource_dom_id": meta_obj.and_then(|m| m.get("resource_dom_id")).cloned(),
                "metadata": meta,
            }))
        }
        Err(e) => SoftDeleteJsonOutcome::Failure(Error::new(e.to_string())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pool::SqlitePool;

    fn soft_delete_test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_soft_del_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "soft_del_{}_{}.sqlite3",
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

    #[test]
    fn schedule_soft_delete_json_emits_deletion_undo_response_shape() {
        let pool = soft_delete_test_pool();
        let rule_id = pool
            .with_write(|conn| {
                conn.execute(
                    "INSERT INTO interaction_rules (user_id, rule_type, source_group, target_group, impact_ratio, is_directional, region, is_reference, created_at, updated_at) \
                     VALUES (1, 'continuous_cultivation', 'A', 'B', 0.5, 1, 'jp', 0, datetime('now'), datetime('now'))",
                    [],
                )?;
                Ok(conn.last_insert_rowid())
            })
            .unwrap();

        let SoftDeleteJsonOutcome::Success(body) = schedule_soft_delete_json(
            pool.clone(),
            "InteractionRule",
            rule_id,
            1,
            "toast",
            5000,
            Some("label"),
        ) else {
            panic!("expected success");
        };

        let undo_token = body["undo_token"].as_str().expect("undo_token");
        assert_eq!(
            body["undo_path"].as_str().expect("undo_path"),
            format!("/undo_deletion?undo_token={undo_token}")
        );
        assert_eq!(body["toast_message"].as_str(), Some("toast"));
        assert_eq!(body["auto_hide_after"].as_i64(), Some(5000));
        assert_eq!(body["redirect_path"].as_str(), Some("/"));
        assert!(body.get("undo_deadline").is_some());
        assert!(body.get("resource_dom_id").is_some());
    }
}
