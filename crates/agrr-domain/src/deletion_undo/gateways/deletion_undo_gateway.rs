//! Ruby: `Domain::DeletionUndo::Gateways::DeletionUndoGateway`

use std::collections::BTreeMap;

use crate::deletion_undo::entities::DeletionUndoEntity;
use crate::deletion_undo::schedule_authorization::SchedulableRecord;

/// Ruby: `Domain::DeletionUndo::Gateways::DeletionUndoGateway`
pub trait DeletionUndoGateway: Send + Sync {
    fn find_by_token(
        &self,
        undo_token: &str,
    ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn expire_if_needed(
        &self,
        event_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn perform_restore(
        &self,
        event_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn mark_failed(
        &self,
        event_id: &str,
        error_message: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn find_schedulable_record(
        &self,
        resource_type: &str,
        resource_id: i64,
    ) -> Result<SchedulableRecord, Box<dyn std::error::Error + Send + Sync>>;

    fn schedule(
        &self,
        resource_type: &str,
        resource_id: i64,
        actor_id: Option<i64>,
        toast_message: Option<&str>,
        auto_hide_after: Option<i64>,
        metadata: &BTreeMap<String, String>,
        validate_before_schedule: bool,
    ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>>;
}
