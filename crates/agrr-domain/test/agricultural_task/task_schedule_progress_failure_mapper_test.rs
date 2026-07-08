// Tests for `mappers/task_schedule_progress_failure_mapper.rs`.

use crate::agricultural_task::task_schedule_sync_error::task_schedule_sync_error_i18n_key;
use crate::agricultural_task::task_schedule_sync_error_keys as keys;

#[test]
fn progress_unavailable_sync_error_uses_agrr_unavailable_key() {
    let err = progress_unavailable_sync_error("daemon socket missing");
    assert_eq!(
        task_schedule_sync_error_i18n_key(&err),
        keys::AGRR_UNAVAILABLE.to_string()
    );
    assert_eq!(err.to_string(), "daemon socket missing");
}
