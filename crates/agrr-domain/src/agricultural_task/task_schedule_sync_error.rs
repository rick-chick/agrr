//! Shared task schedule sync error model and stored-value normalization.

use crate::agricultural_task::task_schedule_sync_error_keys as keys;

const SYNC_ERROR_I18N_PREFIX: &str = "plans.task_schedules.sync_errors.";

#[derive(Debug, Clone)]
pub struct TaskScheduleSyncError {
    i18n_key: &'static str,
    log_detail: String,
    crop_id: Option<i64>,
}

impl TaskScheduleSyncError {
    pub fn new(i18n_key: &'static str, log_detail: impl Into<String>) -> Self {
        Self {
            i18n_key,
            log_detail: log_detail.into(),
            crop_id: None,
        }
    }

    pub fn with_crop_id(
        i18n_key: &'static str,
        log_detail: impl Into<String>,
        crop_id: i64,
    ) -> Self {
        Self {
            i18n_key,
            log_detail: log_detail.into(),
            crop_id: Some(crop_id),
        }
    }

    pub(crate) fn i18n_key(&self) -> &'static str {
        self.i18n_key
    }

    pub(crate) fn crop_id(&self) -> Option<i64> {
        self.crop_id
    }
}

impl std::fmt::Display for TaskScheduleSyncError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.log_detail)
    }
}

impl std::error::Error for TaskScheduleSyncError {}

fn is_known_sync_error_i18n_key(value: &str) -> bool {
    value.starts_with(SYNC_ERROR_I18N_PREFIX)
}

pub fn normalize_stored_sync_error(error: Option<String>) -> Option<String> {
    match error {
        None => None,
        Some(value) if value.is_empty() => None,
        Some(value) if is_known_sync_error_i18n_key(&value) => Some(value),
        Some(_) => Some(keys::GENERIC.to_string()),
    }
}

pub fn task_schedule_sync_error_i18n_key(
    err: &(dyn std::error::Error + Send + Sync + 'static),
) -> String {
    let mut current: Option<&dyn std::error::Error> = Some(err);
    while let Some(e) = current {
        if let Some(ts) = e.downcast_ref::<TaskScheduleSyncError>() {
            return ts.i18n_key().to_string();
        }
        current = e.source();
    }
    keys::GENERIC.to_string()
}

pub fn task_schedule_sync_error_crop_id(
    err: &(dyn std::error::Error + Send + Sync + 'static),
) -> Option<i64> {
    let mut current: Option<&dyn std::error::Error> = Some(err);
    while let Some(e) = current {
        if let Some(ts) = e.downcast_ref::<TaskScheduleSyncError>() {
            return ts.crop_id();
        }
        current = e.source();
    }
    None
}

#[cfg(test)]
mod task_schedule_sync_error_test_inline {
    #[allow(unused_imports)]
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/task_schedule_sync_error_test.rs"
    ));
}
