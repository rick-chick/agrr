use crate::field_cultivation::dtos::FieldCultivationSyncInput;
use crate::field_cultivation::errors::{
    FieldCultivationSyncDuplicateAllocationError, FieldCultivationSyncEmptyError,
};

pub fn validate_sync_input(
    sync_input: &FieldCultivationSyncInput,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if sync_input.field_schedules.is_empty() {
        return Err(Box::new(FieldCultivationSyncEmptyError));
    }

    let mut allocation_ids: Vec<Option<String>> = Vec::new();
    for field_schedule in &sync_input.field_schedules {
        for allocation in &field_schedule.allocations {
            allocation_ids.push(allocation.resolved_allocation_raw());
        }
    }

    let compact_ids: Vec<String> = allocation_ids.into_iter().flatten().collect();
    if compact_ids.len() == compact_ids.iter().collect::<std::collections::HashSet<_>>().len() {
        return Ok(());
    }

    let mut duplicates: Vec<String> = Vec::new();
    for id in &compact_ids {
        if compact_ids.iter().filter(|x| *x == id).count() > 1 && !duplicates.contains(id) {
            duplicates.push(id.clone());
        }
    }
    Err(Box::new(FieldCultivationSyncDuplicateAllocationError::new(
        duplicates,
    )))
}

#[cfg(test)]
mod policies_field_cultivation_sync_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/policies_field_cultivation_sync_policy_test.rs"));
}
