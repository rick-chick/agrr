//! Input for persisting and broadcasting task schedule sync metadata.

pub struct UpdateTaskScheduleSyncStateInput<'a> {
    pub plan_id: i64,
    pub sync_state: &'a str,
    pub sync_error: Option<&'a str>,
    pub sync_error_crop_id: Option<i64>,
}
