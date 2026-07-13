// Tests for `policies/task_schedule_item_preservation_policy.rs`

use crate::agricultural_task::gateways::ProtectableScheduleItemRow;

fn row(source: Option<&str>, has_work_record: bool) -> ProtectableScheduleItemRow {
    ProtectableScheduleItemRow {
        id: 1,
        field_cultivation_id: 10,
        category: "general".into(),
        source: source.map(str::to_string),
        agricultural_task_id: Some(5),
        stage_order: Some(1),
        has_work_record,
    }
}

#[test]
fn preserves_item_with_work_record() {
    assert!(should_preserve(&row(Some("agrr_schedule"), true)));
}

#[test]
fn preserves_manual_entry_without_work_record() {
    assert!(should_preserve(&row(Some("manual_entry"), false)));
}

#[test]
fn preserves_agricultural_task_entry_without_work_record() {
    assert!(should_preserve(&row(Some("agricultural_task_entry"), false)));
}

#[test]
fn does_not_preserve_uncompleted_agrr_schedule_item() {
    assert!(!should_preserve(&row(Some("agrr_schedule"), false)));
}

#[test]
fn does_not_preserve_agrr_source_without_work_record() {
    assert!(!should_preserve(&row(Some("agrr"), false)));
}
