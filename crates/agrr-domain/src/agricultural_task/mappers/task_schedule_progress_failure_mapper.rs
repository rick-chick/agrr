//! Maps progress gateway failures to task schedule sync errors.

use crate::agricultural_task::task_schedule_sync_error::TaskScheduleSyncError;
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;

pub fn progress_unavailable_sync_error(message: &str) -> TaskScheduleSyncError {
    TaskScheduleSyncError::new(sync_errors::AGRR_UNAVAILABLE, message)
}

#[cfg(test)]
mod task_schedule_progress_failure_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/task_schedule_progress_failure_mapper_test.rs"
    ));
}
