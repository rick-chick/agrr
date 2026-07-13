//! Merge newly generated schedule items with protectable existing rows.

use std::collections::HashSet;

use crate::agricultural_task::dtos::TaskScheduleReplaceItem;
use crate::agricultural_task::gateways::ProtectableScheduleItemRow;
use crate::agricultural_task::policies::should_preserve;

#[derive(Debug, Clone)]
pub struct ProtectedMergeResult {
    pub preserved_item_ids: Vec<i64>,
    pub items_to_insert: Vec<TaskScheduleReplaceItem>,
}

pub fn merge_protected_items(
    protectable_items: &[ProtectableScheduleItemRow],
    field_cultivation_id: i64,
    category: &str,
    new_items: Vec<TaskScheduleReplaceItem>,
) -> ProtectedMergeResult {
    let scoped: Vec<&ProtectableScheduleItemRow> = protectable_items
        .iter()
        .filter(|item| {
            item.field_cultivation_id == field_cultivation_id && item.category == category
        })
        .collect();

    let preserved_item_ids: Vec<i64> = scoped
        .iter()
        .filter(|item| should_preserve(item))
        .map(|item| item.id)
        .collect();

    let preserved_match_keys: HashSet<(i64, i32)> = scoped
        .iter()
        .filter(|item| should_preserve(item))
        .filter_map(|item| {
            item.agricultural_task_id
                .zip(item.stage_order)
                .map(|(task_id, stage_order)| (task_id, stage_order))
        })
        .collect();

    let items_to_insert = new_items
        .into_iter()
        .filter(|item| {
            match item.agricultural_task_id.zip(item.stage_order) {
                Some(key) if preserved_match_keys.contains(&key) => false,
                _ => true,
            }
        })
        .collect();

    ProtectedMergeResult {
        preserved_item_ids,
        items_to_insert,
    }
}

#[cfg(test)]
mod mappers_task_schedule_protected_merge_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/mappers_task_schedule_protected_merge_mapper_test.rs"
    ));
}
