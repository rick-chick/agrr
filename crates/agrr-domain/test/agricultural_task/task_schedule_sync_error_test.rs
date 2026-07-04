use crate::agricultural_task::task_schedule_sync_error::{
    normalize_stored_sync_error, task_schedule_sync_error_crop_id,
    task_schedule_sync_error_i18n_key, TaskScheduleSyncError,
};
use crate::agricultural_task::task_schedule_sync_error_keys as keys;

#[test]
fn normalize_stored_sync_error_keeps_known_i18n_key() {
    let key = keys::AGRR_UNAVAILABLE.to_string();
    assert_eq!(
        normalize_stored_sync_error(Some(key.clone())),
        Some(key)
    );
}

#[test]
fn normalize_stored_sync_error_maps_legacy_raw_message_to_generic() {
    assert_eq!(
        normalize_stored_sync_error(Some("worker timeout".into())),
        Some(keys::GENERIC.to_string())
    );
}

#[test]
fn normalize_stored_sync_error_none_for_nullish_values() {
    assert_eq!(normalize_stored_sync_error(None), None);
    assert_eq!(normalize_stored_sync_error(Some(String::new())), None);
}

#[test]
fn task_schedule_sync_error_crop_id_reads_nested_sync_error() {
    let err: Box<dyn std::error::Error + Send + Sync> = Box::new(TaskScheduleSyncError::with_crop_id(
        keys::MISSING_CROP_BLUEPRINTS,
        "no blueprints",
        42,
    ));
    assert_eq!(task_schedule_sync_error_crop_id(err.as_ref()), Some(42));
}

#[test]
fn task_schedule_sync_error_i18n_key_reads_nested_sync_error() {
    let err: Box<dyn std::error::Error + Send + Sync> = Box::new(TaskScheduleSyncError::new(
        keys::MISSING_WEATHER,
        "missing weather",
    ));
    assert_eq!(
        task_schedule_sync_error_i18n_key(err.as_ref()),
        keys::MISSING_WEATHER.to_string()
    );
}
