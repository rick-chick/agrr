//! Persist task schedule sync metadata on cultivation plans.

pub trait TaskScheduleSyncStateGateway: Send + Sync {
    fn update_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn find_sync_state(
        &self,
        plan_id: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>>;
}
