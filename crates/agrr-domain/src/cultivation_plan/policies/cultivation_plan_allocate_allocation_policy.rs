//! Validates agrr `optimize allocate` allocation rows before persisting FieldCultivation.

use serde_json::Value;

use crate::cultivation_plan::helpers::parse_iso_date;

/// True when the row looks like agrr allocate output (not a planning-period placeholder).
pub fn allocation_row_persistable(allocation: &Value) -> bool {
    let Some(start) = allocation
        .get("start_date")
        .and_then(|v| v.as_str())
        .and_then(parse_iso_date)
    else {
        return false;
    };
    let Some(end) = allocation
        .get("completion_date")
        .and_then(|v| v.as_str())
        .and_then(parse_iso_date)
    else {
        return false;
    };
    if end < start {
        return false;
    }

    let growth_days = allocation
        .get("growth_days")
        .and_then(|v| v.as_i64())
        .unwrap_or(0);
    if growth_days < 1 {
        return false;
    }

    let area_used = allocation
        .get("area_used")
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0);
    if area_used <= 0.0 {
        return false;
    }

    let crop_name = allocation
        .get("crop_name")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();
    !crop_name.is_empty()
}

/// True when at least one allocation under `field_schedules` is persistable.
pub fn allocation_result_persistable(allocation_result: &Value) -> bool {
    let Some(schedules) = allocation_result
        .get("field_schedules")
        .and_then(|v| v.as_array())
    else {
        return false;
    };

    schedules.iter().any(|schedule| {
        schedule
            .get("allocations")
            .and_then(|v| v.as_array())
            .is_some_and(|allocations| {
                allocations
                    .iter()
                    .any(allocation_row_persistable)
            })
    })
}

#[cfg(test)]
mod policies_cultivation_plan_allocate_allocation_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_cultivation_plan_allocate_allocation_policy_test.rs"
    ));
}
