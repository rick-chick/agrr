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
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::{
        FieldCultivationSyncAllocationInput, FieldCultivationSyncFieldScheduleInput,
        FieldCultivationSyncInput,
    };
    use time::macros::date;

    #[test]
    fn rejects_empty_schedules() {
        let input = FieldCultivationSyncInput {
            field_schedules: vec![],
            optimization_summary: None,
            total_profit: None,
            total_revenue: None,
            total_cost: None,
            optimization_time: None,
            algorithm_used: None,
            is_optimal: None,
        };
        assert!(validate_sync_input(&input)
            .unwrap_err()
            .downcast_ref::<FieldCultivationSyncEmptyError>()
            .is_some());
    }

    #[test]
    fn rejects_duplicate_allocation_ids() {
        let allocation = FieldCultivationSyncAllocationInput {
            allocation_id: Some(1),
            external_allocation_id: None,
            crop_id: "c".into(),
            start_date: date!(2026 - 01 - 01),
            completion_date: date!(2026 - 01 - 02),
            area_used: None,
            area: None,
            total_cost: None,
            cost: None,
            expected_revenue: None,
            revenue: None,
            profit: None,
            accumulated_gdd: None,
        };
        let input = FieldCultivationSyncInput {
            field_schedules: vec![
                FieldCultivationSyncFieldScheduleInput {
                    field_id: Some(1),
                    allocations: vec![allocation.clone(), allocation],
                },
            ],
            optimization_summary: None,
            total_profit: None,
            total_revenue: None,
            total_cost: None,
            optimization_time: None,
            algorithm_used: None,
            is_optimal: None,
        };
        assert!(validate_sync_input(&input)
            .unwrap_err()
            .downcast_ref::<FieldCultivationSyncDuplicateAllocationError>()
            .is_some());
    }
}
