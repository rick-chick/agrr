// Tests for `policies/field_cultivation_sync_policy.rs` (Ruby parity under test/domain/field_cultivation/).

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
