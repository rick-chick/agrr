//! Ruby: `Domain::CultivationPlan::Policies::CultivationPlanFieldPolicy`

use crate::cultivation_plan::constants::MAX_FIELDS;

pub fn invalid_field_area(field_area: f64) -> bool {
    field_area <= 0.0
}

pub fn max_fields_reached(existing_field_count: i32) -> bool {
    existing_field_count >= MAX_FIELDS
}

pub fn cannot_remove_last_field(existing_field_count: i32) -> bool {
    existing_field_count <= 1
}

pub fn cannot_remove_with_cultivations(cultivation_count: i32) -> bool {
    cultivation_count > 0
}

#[cfg(test)]
mod policies_cultivation_plan_field_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_cultivation_plan_field_policy_test.rs"));
}
