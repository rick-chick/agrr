// Tests for `mappers/task_schedule_protected_merge_mapper.rs`

use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
use crate::agricultural_task::dtos::TaskScheduleReplaceItem;
use crate::agricultural_task::gateways::ProtectableScheduleItemRow;
use rust_decimal::Decimal;
use std::str::FromStr;
use time::{Date, Month};

fn protectable(
    id: i64,
    source: &str,
    has_work_record: bool,
    agricultural_task_id: Option<i64>,
    stage_order: Option<i32>,
) -> ProtectableScheduleItemRow {
    ProtectableScheduleItemRow {
        id,
        field_cultivation_id: 100,
        category: "general".into(),
        source: Some(source.into()),
        agricultural_task_id,
        stage_order,
        has_work_record,
    }
}

fn replace_item(
    name: &str,
    agricultural_task_id: Option<i64>,
    stage_order: Option<i32>,
) -> TaskScheduleReplaceItem {
    TaskScheduleReplaceItem {
        task_type: FIELD_WORK.to_string(),
        agricultural_task_id,
        name: name.to_string(),
        description: None,
        stage_name: None,
        stage_order,
        gdd_trigger: Decimal::from_str("10").unwrap(),
        gdd_tolerance: None,
        scheduled_date: Date::from_calendar_date(2026, Month::June, 1).unwrap(),
        priority: None,
        source: Some("agrr_schedule".into()),
        status: PLANNED.to_string(),
        weather_dependency: None,
        time_per_sqm: None,
        amount: None,
        amount_unit: None,
    }
}

#[test]
fn merge_keeps_preserved_ids_and_inserts_all_new_when_no_match_keys() {
    let protectable = vec![
        protectable(1, "manual_entry", false, None, None),
        protectable(2, "agrr_schedule", true, Some(11), Some(1)),
    ];
    let new_items = vec![
        replace_item("new agrr", Some(99), Some(2)),
        replace_item("another", None, None),
    ];

    let result = merge_protected_items(&protectable, 100, "general", new_items);

    assert_eq!(vec![1, 2], result.preserved_item_ids);
    assert_eq!(2, result.items_to_insert.len());
}

#[test]
fn merge_suppresses_new_item_with_matching_agricultural_task_and_stage_order() {
    let protectable = vec![protectable(7, "agrr_schedule", true, Some(11), Some(1))];
    let new_items = vec![
        replace_item("duplicate", Some(11), Some(1)),
        replace_item("fresh", Some(12), Some(1)),
    ];

    let result = merge_protected_items(&protectable, 100, "general", new_items);

    assert_eq!(vec![7], result.preserved_item_ids);
    assert_eq!(1, result.items_to_insert.len());
    assert_eq!(Some(12), result.items_to_insert[0].agricultural_task_id);
}

#[test]
fn merge_ignores_unpreserved_items_for_field_category() {
    let protectable = vec![protectable(3, "agrr_schedule", false, Some(11), Some(1))];
    let new_items = vec![replace_item("fresh", Some(11), Some(1))];

    let result = merge_protected_items(&protectable, 100, "general", new_items);

    assert!(result.preserved_item_ids.is_empty());
    assert_eq!(1, result.items_to_insert.len());
}

#[test]
fn merge_filters_other_field_or_category() {
    let protectable = vec![ProtectableScheduleItemRow {
        id: 9,
        field_cultivation_id: 200,
        category: "fertilizer".into(),
        source: Some("manual_entry".into()),
        agricultural_task_id: None,
        stage_order: None,
        has_work_record: false,
    }];
    let new_items = vec![replace_item("only general", Some(1), Some(1))];

    let result = merge_protected_items(&protectable, 100, "general", new_items);

    assert!(result.preserved_item_ids.is_empty());
    assert_eq!(1, result.items_to_insert.len());
}
