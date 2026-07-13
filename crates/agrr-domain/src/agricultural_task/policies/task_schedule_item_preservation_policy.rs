//! Domain policy: which existing task schedule items survive regeneration.

use crate::agricultural_task::gateways::ProtectableScheduleItemRow;

const MANUAL_ENTRY: &str = "manual_entry";
const AGRICULTURAL_TASK_ENTRY: &str = "agricultural_task_entry";

pub fn should_preserve(item: &ProtectableScheduleItemRow) -> bool {
    item.has_work_record || is_manual_source(item.source.as_deref())
}

fn is_manual_source(source: Option<&str>) -> bool {
    matches!(
        source,
        Some(MANUAL_ENTRY) | Some(AGRICULTURAL_TASK_ENTRY)
    )
}

#[cfg(test)]
mod policies_task_schedule_item_preservation_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/policies_task_schedule_item_preservation_policy_test.rs"
    ));
}
