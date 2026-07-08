// Tests for `mappers/task_schedule_progress_mapper.rs`.

use rust_decimal::Decimal;
use std::str::FromStr;

use crate::agricultural_task::task_schedule_sync_error::{
    task_schedule_sync_error_crop_id, task_schedule_sync_error_i18n_key,
};
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;

fn dec(s: &str) -> Decimal {
    Decimal::from_str(s).unwrap()
}

#[test]
fn progress_records_from_json_parses_records() {
    let data = serde_json::json!({
        "progress_records": [
            { "date": "2025-04-01T00:00:00", "cumulative_gdd": 0.0 },
            { "date": "2025-04-04T00:00:00", "cumulative_gdd": 120.0 }
        ]
    });

    let records = progress_records_from_json(&data);

    assert_eq!(records.len(), 2);
    assert_eq!(records[0].date, "2025-04-01T00:00:00");
    assert_eq!(records[0].cumulative_gdd, Some(dec("0.0")));
    assert_eq!(records[1].date, "2025-04-04T00:00:00");
    assert_eq!(records[1].cumulative_gdd, Some(dec("120.0")));
}

#[test]
fn date_for_gdd_returns_gdd_date_not_found_with_crop_id_when_matching_record_date_unparseable() {
    let records = vec![ProgressRecord {
        date: "not-a-date".into(),
        cumulative_gdd: Some(dec("120.0")),
    }];
    let target_gdd = dec("100.0");
    let crop_id = 42;

    let err = date_for_gdd(&records, target_gdd, None, crop_id).unwrap_err();

    assert_eq!(
        task_schedule_sync_error_i18n_key(err.as_ref()),
        sync_errors::GDD_DATE_NOT_FOUND.to_string()
    );
    assert_eq!(task_schedule_sync_error_crop_id(err.as_ref()), Some(crop_id));
}

#[test]
fn date_for_gdd_returns_gdd_date_not_found_with_crop_id_when_no_match() {
    let records = vec![ProgressRecord {
        date: "2025-04-01T00:00:00".into(),
        cumulative_gdd: Some(dec("10.0")),
    }];
    let target_gdd = dec("999.0");
    let crop_id = 42;

    let err = date_for_gdd(&records, target_gdd, None, crop_id).unwrap_err();

    assert_eq!(
        task_schedule_sync_error_i18n_key(err.as_ref()),
        sync_errors::GDD_DATE_NOT_FOUND.to_string()
    );
    assert_eq!(task_schedule_sync_error_crop_id(err.as_ref()), Some(crop_id));
}
