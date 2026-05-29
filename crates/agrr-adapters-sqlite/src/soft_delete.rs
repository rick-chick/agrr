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
            SoftDeleteJsonOutcome::Success(json!({
                "undo_token": scheduled.undo_token,
                "metadata": meta,
                "toast_message": meta.get("toast_message"),
                "auto_hide_after": meta.get("auto_hide_after"),
                "resource_type": resource_type,
                "resource_id": resource_id.to_string(),
            }))
        }
        Err(e) => SoftDeleteJsonOutcome::Failure(Error::new(e.to_string())),
    }
}
