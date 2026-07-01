//! Broadcast task schedule sync state to plan Cable subscribers.

pub trait TaskScheduleSyncBroadcastPort: Send + Sync {
    fn broadcast_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
    );
}
